/// Externally owned memory.
path: []const u8,
index: File.Index,

symtab: std.MultiArrayList(Nlist) = .{},

symbols: std.ArrayListUnmanaged(Symbol.Index) = .{},
atoms: std.ArrayListUnmanaged(Atom.Index) = .{},

/// Table of tracked Decls.
decls: DeclTable = .{},

/// A table of relocations.
relocs: RelocationTable = .{},

output_symtab_ctx: MachO.SymtabCtx = .{},

pub fn init(self: *ZigObject, macho_file: *MachO) !void {
    const comp = macho_file.base.comp;
    const gpa = comp.gpa;

    try self.atoms.append(gpa, 0); // null input section
}

pub fn deinit(self: *ZigObject, allocator: Allocator) void {
    self.symtab.deinit(allocator);
    self.symbols.deinit(allocator);
    self.atoms.deinit(allocator);

    {
        var it = self.decls.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.exports.deinit(allocator);
        }
        self.decls.deinit(allocator);
    }

    for (self.relocs.items) |*list| {
        list.deinit(allocator);
    }
    self.relocs.deinit(allocator);
}

fn addNlist(self: *ZigObject, allocator: Allocator) !Symbol.Index {
    try self.symtab.ensureUnusedCapacity(allocator, 1);
    const index = @as(Symbol.Index, @intCast(self.symtab.addOneAssumeCapacity()));
    self.symtab.set(index, .{
        .nlist = MachO.null_sym,
        .size = 0,
        .atom = 0,
    });
    return index;
}

pub fn addAtom(self: *ZigObject, macho_file: *MachO) !Symbol.Index {
    const gpa = macho_file.base.comp.gpa;
    const atom_index = try macho_file.addAtom();
    const symbol_index = try macho_file.addSymbol();
    const nlist_index = try self.addNlist(gpa);

    try self.atoms.append(gpa, atom_index);
    try self.symbols.append(gpa, symbol_index);

    const atom = macho_file.getAtom(atom_index).?;
    atom.file = self.index;

    const symbol = macho_file.getSymbol(symbol_index);
    symbol.file = self.index;
    symbol.atom = atom_index;

    self.symtab.items(.atom)[nlist_index] = atom_index;
    symbol.nlist_idx = nlist_index;

    const relocs_index = @as(u32, @intCast(self.relocs.items.len));
    const relocs = try self.relocs.addOne(gpa);
    relocs.* = .{};
    atom.relocs = .{ .pos = relocs_index, .len = 0 };

    return symbol_index;
}

pub fn getAtomRelocs(self: *ZigObject, atom: Atom) []const Relocation {
    const relocs = self.relocs.items[atom.relocs.pos];
    return relocs.items[0..atom.relocs.len];
}

pub fn resolveSymbols(self: *ZigObject, macho_file: *MachO) void {
    _ = self;
    _ = macho_file;
    @panic("TODO resolveSymbols");
}

pub fn resetGlobals(self: *ZigObject, macho_file: *MachO) void {
    for (self.symbols.items, 0..) |sym_index, nlist_idx| {
        if (!self.symtab.items(.nlist)[nlist_idx].ext()) continue;
        const sym = macho_file.getSymbol(sym_index);
        const name = sym.name;
        sym.* = .{};
        sym.name = name;
    }
}

pub fn markLive(self: *ZigObject, macho_file: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.symbols.items, 0..) |index, nlist_idx| {
        const nlist = self.symtab.items(.nlist)[nlist_idx];
        if (!nlist.ext()) continue;

        const sym = macho_file.getSymbol(index);
        const file = sym.getFile(macho_file) orelse continue;
        const should_keep = nlist.undf() or (nlist.tentative() and !sym.flags.tentative);
        if (should_keep and file == .object and !file.object.alive) {
            file.object.alive = true;
            file.object.markLive(macho_file);
        }
    }
}

pub fn calcSymtabSize(self: *ZigObject, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.symbols.items) |sym_index| {
        const sym = macho_file.getSymbol(sym_index);
        const file = sym.getFile(macho_file) orelse continue;
        if (file.getIndex() != self.index) continue;
        if (sym.getAtom(macho_file)) |atom| if (!atom.flags.alive) continue;
        sym.flags.output_symtab = true;
        if (sym.isLocal()) {
            try sym.addExtra(.{ .symtab = self.output_symtab_ctx.nlocals }, macho_file);
            self.output_symtab_ctx.nlocals += 1;
        } else if (sym.flags.@"export") {
            try sym.addExtra(.{ .symtab = self.output_symtab_ctx.nexports }, macho_file);
            self.output_symtab_ctx.nexports += 1;
        } else {
            assert(sym.flags.import);
            try sym.addExtra(.{ .symtab = self.output_symtab_ctx.nimports }, macho_file);
            self.output_symtab_ctx.nimports += 1;
        }
        self.output_symtab_ctx.strsize += @as(u32, @intCast(sym.getName(macho_file).len + 1));
    }
}

pub fn writeSymtab(self: ZigObject, macho_file: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.symbols.items) |sym_index| {
        const sym = macho_file.getSymbol(sym_index);
        const file = sym.getFile(macho_file) orelse continue;
        if (file.getIndex() != self.index) continue;
        const idx = sym.getOutputSymtabIndex(macho_file) orelse continue;
        const n_strx = @as(u32, @intCast(macho_file.strtab.items.len));
        macho_file.strtab.appendSliceAssumeCapacity(sym.getName(macho_file));
        macho_file.strtab.appendAssumeCapacity(0);
        const out_sym = &macho_file.symtab.items[idx];
        out_sym.n_strx = n_strx;
        sym.setOutputSym(macho_file, out_sym);
    }
}

pub fn getInputSection(self: ZigObject, atom: Atom, macho_file: *MachO) macho.section_64 {
    _ = self;
    var sect = macho_file.sections.items(.header)[atom.out_n_sect];
    sect.addr = 0;
    sect.offset = 0;
    sect.size = atom.size;
    sect.@"align" = atom.alignment.toLog2Units();
    return sect;
}

pub fn flushModule(self: *ZigObject, macho_file: *MachO) !void {
    _ = self;
    _ = macho_file;
    @panic("TODO flushModule");
}

pub fn getDeclVAddr(
    self: *ZigObject,
    macho_file: *MachO,
    decl_index: InternPool.DeclIndex,
    reloc_info: link.File.RelocInfo,
) !u64 {
    _ = self;
    _ = macho_file;
    _ = decl_index;
    _ = reloc_info;
    @panic("TODO getDeclVAddr");
}

pub fn getAnonDeclVAddr(
    self: *ZigObject,
    macho_file: *MachO,
    decl_val: InternPool.Index,
    reloc_info: link.File.RelocInfo,
) !u64 {
    _ = self;
    _ = macho_file;
    _ = decl_val;
    _ = reloc_info;
    @panic("TODO getAnonDeclVAddr");
}

pub fn lowerAnonDecl(
    self: *ZigObject,
    macho_file: *MachO,
    decl_val: InternPool.Index,
    explicit_alignment: InternPool.Alignment,
    src_loc: Module.SrcLoc,
) !codegen.Result {
    _ = self;
    _ = macho_file;
    _ = decl_val;
    _ = explicit_alignment;
    _ = src_loc;
    @panic("TODO lowerAnonDecl");
}

pub fn freeDecl(self: *ZigObject, macho_file: *MachO, decl_index: InternPool.DeclIndex) void {
    _ = self;
    _ = macho_file;
    _ = decl_index;
    @panic("TODO freeDecl");
}

pub fn updateFunc(
    self: *ZigObject,
    macho_file: *MachO,
    mod: *Module,
    func_index: InternPool.Index,
    air: Air,
    liveness: Liveness,
) !void {
    _ = self;
    _ = macho_file;
    _ = mod;
    _ = func_index;
    _ = air;
    _ = liveness;
    @panic("TODO updateFunc");
}

pub fn updateDecl(
    self: *ZigObject,
    macho_file: *MachO,
    mod: *Module,
    decl_index: InternPool.DeclIndex,
) link.File.UpdateDeclError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const decl = mod.declPtr(decl_index);

    if (decl.val.getExternFunc(mod)) |_| {
        return;
    }

    if (decl.isExtern(mod)) {
        // Extern variable gets a __got entry only
        const variable = decl.getOwnedVariable(mod).?;
        const name = mod.intern_pool.stringToSlice(decl.name);
        const lib_name = mod.intern_pool.stringToSliceUnwrap(variable.lib_name);
        const index = try self.getGlobalSymbol(macho_file, name, lib_name);
        macho_file.getSymbol(index).flags.needs_got = true;
        return;
    }

    const sym_index = try self.getOrCreateMetadataForDecl(macho_file, decl_index);
    // TODO: free relocs if any

    const gpa = macho_file.base.comp.gpa;
    var code_buffer = std.ArrayList(u8).init(gpa);
    defer code_buffer.deinit();

    var decl_state: ?Dwarf.DeclState = null; // TODO: Dwarf
    defer if (decl_state) |*ds| ds.deinit();

    const decl_val = if (decl.val.getVariable(mod)) |variable| Value.fromInterned(variable.init) else decl.val;
    const dio: codegen.DebugInfoOutput = if (decl_state) |*ds| .{ .dwarf = ds } else .none;
    const res =
        try codegen.generateSymbol(&macho_file.base, decl.srcLoc(mod), .{
        .ty = decl.ty,
        .val = decl_val,
    }, &code_buffer, dio, .{
        .parent_atom_index = sym_index,
    });

    const code = switch (res) {
        .ok => code_buffer.items,
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try mod.failed_decls.put(mod.gpa, decl_index, em);
            return;
        },
    };
    _ = code;
    // const addr = try self.updateDeclCode(decl_index, code);

    // if (decl_state) |*ds| {
    //     try self.d_sym.?.dwarf.commitDeclState(
    //         mod,
    //         decl_index,
    //         addr,
    //         self.getAtom(atom_index).size,
    //         ds,
    //     );
    // }

    // // Since we updated the vaddr and the size, each corresponding export symbol also
    // // needs to be updated.
    // try self.updateExports(mod, .{ .decl_index = decl_index }, mod.getDeclExports(decl_index));
}

pub fn lowerUnnamedConst(
    self: *ZigObject,
    macho_file: *MachO,
    typed_value: TypedValue,
    decl_index: InternPool.DeclIndex,
) !u32 {
    _ = self;
    _ = macho_file;
    _ = typed_value;
    _ = decl_index;
    @panic("TODO lowerUnnamedConst");
}

pub fn updateExports(
    self: *ZigObject,
    macho_file: *MachO,
    mod: *Module,
    exported: Module.Exported,
    exports: []const *Module.Export,
) link.File.UpdateExportsError!void {
    _ = self;
    _ = macho_file;
    _ = mod;
    _ = exported;
    _ = exports;
    @panic("TODO updateExports");
}

/// Must be called only after a successful call to `updateDecl`.
pub fn updateDeclLineNumber(
    self: *ZigObject,
    mod: *Module,
    decl_index: InternPool.DeclIndex,
) !void {
    _ = self;
    _ = mod;
    _ = decl_index;
    @panic("TODO updateDeclLineNumber");
}

pub fn deleteDeclExport(
    self: *ZigObject,
    macho_file: *MachO,
    decl_index: InternPool.DeclIndex,
    name: InternPool.NullTerminatedString,
) void {
    _ = self;
    _ = macho_file;
    _ = decl_index;
    _ = name;
    @panic("TODO deleteDeclExport");
}

pub fn getGlobalSymbol(self: *ZigObject, macho_file: *MachO, name: []const u8, lib_name: ?[]const u8) !u32 {
    _ = self;
    _ = macho_file;
    _ = name;
    _ = lib_name;
    @panic("TODO getGlobalSymbol");
}

pub fn getOrCreateMetadataForDecl(
    self: *ZigObject,
    macho_file: *MachO,
    decl_index: InternPool.DeclIndex,
) !Symbol.Index {
    const gpa = macho_file.base.comp.gpa;
    const gop = try self.decls.getOrPut(gpa, decl_index);
    if (!gop.found_existing) {
        const any_non_single_threaded = macho_file.base.comp.config.any_non_single_threaded;
        const sym_index = try self.addAtom(macho_file);
        const mod = macho_file.base.comp.module.?;
        const decl = mod.declPtr(decl_index);
        const sym = macho_file.getSymbol(self.symbols.items[sym_index]);
        if (decl.getOwnedVariable(mod)) |variable| {
            if (variable.is_threadlocal and any_non_single_threaded) {
                sym.flags.tlv = true;
            }
        }
        if (!sym.flags.tlv) {
            sym.flags.needs_zig_got = true;
        }
        gop.value_ptr.* = .{ .symbol_index = sym_index };
    }
    return gop.value_ptr.symbol_index;
}

pub fn asFile(self: *ZigObject) File {
    return .{ .zig_object = self };
}

pub fn fmtSymtab(self: *ZigObject, macho_file: *MachO) std.fmt.Formatter(formatSymtab) {
    return .{ .data = .{
        .self = self,
        .macho_file = macho_file,
    } };
}

const FormatContext = struct {
    self: *ZigObject,
    macho_file: *MachO,
};

fn formatSymtab(
    ctx: FormatContext,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = unused_fmt_string;
    _ = options;
    try writer.writeAll("  symbols\n");
    for (ctx.self.symbols.items) |index| {
        const sym = ctx.macho_file.getSymbol(index);
        try writer.print("    {}\n", .{sym.fmt(ctx.macho_file)});
    }
}

pub fn fmtAtoms(self: *ZigObject, macho_file: *MachO) std.fmt.Formatter(formatAtoms) {
    return .{ .data = .{
        .self = self,
        .macho_file = macho_file,
    } };
}

fn formatAtoms(
    ctx: FormatContext,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = unused_fmt_string;
    _ = options;
    try writer.writeAll("  atoms\n");
    for (ctx.self.atoms.items) |atom_index| {
        const atom = ctx.macho_file.getAtom(atom_index) orelse continue;
        try writer.print("    {}\n", .{atom.fmt(ctx.macho_file)});
    }
}

const DeclMetadata = struct {
    symbol_index: Symbol.Index,
    /// A list of all exports aliases of this Decl.
    exports: std.ArrayListUnmanaged(Symbol.Index) = .{},

    fn @"export"(m: DeclMetadata, zig_object: *ZigObject, macho_file: *MachO, name: []const u8) ?*u32 {
        for (m.exports.items) |*exp| {
            const nlist = zig_object.symtab.items(.nlist)[exp.*];
            const exp_name = macho_file.strings.getAssumeExists(nlist.n_strx);
            if (mem.eql(u8, name, exp_name)) return exp;
        }
        return null;
    }
};
const DeclTable = std.AutoHashMapUnmanaged(InternPool.DeclIndex, DeclMetadata);

const RelocationTable = std.ArrayListUnmanaged(std.ArrayListUnmanaged(Relocation));

const assert = std.debug.assert;
const builtin = @import("builtin");
const codegen = @import("../../codegen.zig");
const link = @import("../../link.zig");
const log = std.log.scoped(.link);
const macho = std.macho;
const mem = std.mem;
const trace = @import("../../tracy.zig").trace;
const std = @import("std");

const Air = @import("../../Air.zig");
const Allocator = std.mem.Allocator;
const Archive = @import("Archive.zig");
const Atom = @import("Atom.zig");
const Dwarf = @import("../Dwarf.zig");
const File = @import("file.zig").File;
const InternPool = @import("../../InternPool.zig");
const Liveness = @import("../../Liveness.zig");
const MachO = @import("../MachO.zig");
const Nlist = Object.Nlist;
const Module = @import("../../Module.zig");
const Object = @import("Object.zig");
const Relocation = @import("Relocation.zig");
const Symbol = @import("Symbol.zig");
const StringTable = @import("../StringTable.zig");
const Type = @import("../../type.zig").Type;
const Value = @import("../../value.zig").Value;
const TypedValue = @import("../../TypedValue.zig");
const ZigObject = @This();
