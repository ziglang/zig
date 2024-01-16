/// Externally owned memory.
path: []const u8,
index: File.Index,

symtab: std.MultiArrayList(Nlist) = .{},

symbols: std.ArrayListUnmanaged(Symbol.Index) = .{},
atoms: std.ArrayListUnmanaged(Atom.Index) = .{},

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
    _ = self;
    _ = macho_file;
    _ = mod;
    _ = decl_index;
    @panic("TODO updateDecl");
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

const Nlist = struct {
    nlist: macho.nlist_64,
    size: u64,
    atom: Atom.Index,
};

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
const Module = @import("../../Module.zig");
const Object = @import("Object.zig");
const Symbol = @import("Symbol.zig");
const StringTable = @import("../StringTable.zig");
const Type = @import("../../type.zig").Type;
const Value = @import("../../value.zig").Value;
const TypedValue = @import("../../TypedValue.zig");
const ZigObject = @This();
