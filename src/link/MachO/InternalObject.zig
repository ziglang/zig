index: File.Index,

sections: std.MultiArrayList(Section) = .{},
atoms: std.ArrayListUnmanaged(Atom.Index) = .{},
symbols: std.ArrayListUnmanaged(Symbol.Index) = .{},

objc_methnames: std.ArrayListUnmanaged(u8) = .{},
objc_selrefs: [@sizeOf(u64)]u8 = [_]u8{0} ** @sizeOf(u64),

num_rebase_relocs: u32 = 0,
output_symtab_ctx: MachO.SymtabCtx = .{},

pub fn deinit(self: *InternalObject, allocator: Allocator) void {
    for (self.sections.items(.relocs)) |*relocs| {
        relocs.deinit(allocator);
    }
    self.sections.deinit(allocator);
    self.atoms.deinit(allocator);
    self.symbols.deinit(allocator);
    self.objc_methnames.deinit(allocator);
}

pub fn addSymbol(self: *InternalObject, name: [:0]const u8, macho_file: *MachO) !Symbol.Index {
    const gpa = macho_file.base.comp.gpa;
    try self.symbols.ensureUnusedCapacity(gpa, 1);
    const off = try macho_file.strings.insert(gpa, name);
    const gop = try macho_file.getOrCreateGlobal(off);
    self.symbols.addOneAssumeCapacity().* = gop.index;
    const sym = macho_file.getSymbol(gop.index);
    sym.file = self.index;
    sym.value = 0;
    sym.atom = 0;
    sym.nlist_idx = 0;
    sym.flags = .{ .global = true };
    return gop.index;
}

/// Creates a fake input sections __TEXT,__objc_methname and __DATA,__objc_selrefs.
pub fn addObjcMsgsendSections(self: *InternalObject, sym_name: []const u8, macho_file: *MachO) !Atom.Index {
    const methname_atom_index = try self.addObjcMethnameSection(sym_name, macho_file);
    return try self.addObjcSelrefsSection(methname_atom_index, macho_file);
}

fn addObjcMethnameSection(self: *InternalObject, methname: []const u8, macho_file: *MachO) !Atom.Index {
    const gpa = macho_file.base.comp.gpa;
    const atom_index = try macho_file.addAtom();
    try self.atoms.append(gpa, atom_index);

    const atom = macho_file.getAtom(atom_index).?;
    atom.atom_index = atom_index;
    atom.file = self.index;
    atom.size = methname.len + 1;
    atom.alignment = .@"1";

    const n_sect = try self.addSection(gpa, "__TEXT", "__objc_methname");
    const sect = &self.sections.items(.header)[n_sect];
    sect.flags = macho.S_CSTRING_LITERALS;
    sect.size = atom.size;
    sect.@"align" = 0;
    atom.n_sect = n_sect;
    self.sections.items(.extra)[n_sect].is_objc_methname = true;

    sect.offset = @intCast(self.objc_methnames.items.len);
    try self.objc_methnames.ensureUnusedCapacity(gpa, methname.len + 1);
    self.objc_methnames.writer(gpa).print("{s}\x00", .{methname}) catch unreachable;

    return atom_index;
}

fn addObjcSelrefsSection(self: *InternalObject, methname_atom_index: Atom.Index, macho_file: *MachO) !Atom.Index {
    const gpa = macho_file.base.comp.gpa;
    const atom_index = try macho_file.addAtom();
    try self.atoms.append(gpa, atom_index);

    const atom = macho_file.getAtom(atom_index).?;
    atom.atom_index = atom_index;
    atom.file = self.index;
    atom.size = @sizeOf(u64);
    atom.alignment = .@"8";

    const n_sect = try self.addSection(gpa, "__DATA", "__objc_selrefs");
    const sect = &self.sections.items(.header)[n_sect];
    sect.flags = macho.S_LITERAL_POINTERS | macho.S_ATTR_NO_DEAD_STRIP;
    sect.offset = 0;
    sect.size = atom.size;
    sect.@"align" = 3;
    atom.n_sect = n_sect;
    self.sections.items(.extra)[n_sect].is_objc_selref = true;

    const relocs = &self.sections.items(.relocs)[n_sect];
    try relocs.ensureUnusedCapacity(gpa, 1);
    relocs.appendAssumeCapacity(.{
        .tag = .local,
        .offset = 0,
        .target = methname_atom_index,
        .addend = 0,
        .type = .unsigned,
        .meta = .{
            .pcrel = false,
            .length = 3,
            .symbolnum = 0, // Only used when synthesising unwind records so can be anything
            .has_subtractor = false,
        },
    });
    try atom.addExtra(.{ .rel_index = 0, .rel_count = 1 }, macho_file);
    atom.flags.relocs = true;
    self.num_rebase_relocs += 1;

    return atom_index;
}

pub fn resolveLiterals(self: InternalObject, lp: *MachO.LiteralPool, macho_file: *MachO) !void {
    const gpa = macho_file.base.comp.gpa;

    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();

    const slice = self.sections.slice();
    for (slice.items(.header), self.atoms.items, 0..) |header, atom_index, n_sect| {
        if (Object.isCstringLiteral(header) or Object.isFixedSizeLiteral(header)) {
            const data = try self.getSectionData(@intCast(n_sect));
            const atom = macho_file.getAtom(atom_index).?;
            const res = try lp.insert(gpa, header.type(), data);
            if (!res.found_existing) {
                res.atom.* = atom_index;
            }
            atom.flags.literal_pool = true;
            try atom.addExtra(.{ .literal_index = res.index }, macho_file);
        } else if (Object.isPtrLiteral(header)) {
            const atom = macho_file.getAtom(atom_index).?;
            const relocs = atom.getRelocs(macho_file);
            assert(relocs.len == 1);
            const rel = relocs[0];
            assert(rel.tag == .local);
            const target = macho_file.getAtom(rel.target).?;
            const addend = std.math.cast(u32, rel.addend) orelse return error.Overflow;
            const target_size = std.math.cast(usize, target.size) orelse return error.Overflow;
            try buffer.ensureUnusedCapacity(target_size);
            buffer.resize(target_size) catch unreachable;
            try target.getData(macho_file, buffer.items);
            const res = try lp.insert(gpa, header.type(), buffer.items[addend..]);
            buffer.clearRetainingCapacity();
            if (!res.found_existing) {
                res.atom.* = atom_index;
            }
            atom.flags.literal_pool = true;
            try atom.addExtra(.{ .literal_index = res.index }, macho_file);
        }
    }
}

pub fn dedupLiterals(self: InternalObject, lp: MachO.LiteralPool, macho_file: *MachO) void {
    for (self.atoms.items) |atom_index| {
        const atom = macho_file.getAtom(atom_index) orelse continue;
        if (!atom.flags.alive) continue;
        if (!atom.flags.relocs) continue;

        const relocs = blk: {
            const extra = atom.getExtra(macho_file).?;
            const relocs = self.sections.items(.relocs)[atom.n_sect].items;
            break :blk relocs[extra.rel_index..][0..extra.rel_count];
        };
        for (relocs) |*rel| switch (rel.tag) {
            .local => {
                const target = macho_file.getAtom(rel.target).?;
                if (target.getLiteralPoolIndex(macho_file)) |lp_index| {
                    const lp_atom = lp.getAtom(lp_index, macho_file);
                    if (target.atom_index != lp_atom.atom_index) {
                        lp_atom.alignment = lp_atom.alignment.max(target.alignment);
                        target.flags.alive = false;
                        rel.target = lp_atom.atom_index;
                    }
                }
            },
            .@"extern" => {
                const target_sym = rel.getTargetSymbol(macho_file);
                if (target_sym.getAtom(macho_file)) |target_atom| {
                    if (target_atom.getLiteralPoolIndex(macho_file)) |lp_index| {
                        const lp_atom = lp.getAtom(lp_index, macho_file);
                        if (target_atom.atom_index != lp_atom.atom_index) {
                            lp_atom.alignment = lp_atom.alignment.max(target_atom.alignment);
                            target_atom.flags.alive = false;
                            target_sym.atom = lp_atom.atom_index;
                        }
                    }
                }
            },
        };
    }

    for (self.symbols.items) |sym_index| {
        const sym = macho_file.getSymbol(sym_index);
        if (!sym.flags.objc_stubs) continue;
        var extra = sym.getExtra(macho_file).?;
        const atom = macho_file.getAtom(extra.objc_selrefs).?;
        if (atom.getLiteralPoolIndex(macho_file)) |lp_index| {
            const lp_atom = lp.getAtom(lp_index, macho_file);
            if (atom.atom_index != lp_atom.atom_index) {
                lp_atom.alignment = lp_atom.alignment.max(atom.alignment);
                atom.flags.alive = false;
                extra.objc_selrefs = lp_atom.atom_index;
                sym.setExtra(extra, macho_file);
            }
        }
    }
}

pub fn calcSymtabSize(self: *InternalObject, macho_file: *MachO) !void {
    for (self.symbols.items) |sym_index| {
        const sym = macho_file.getSymbol(sym_index);
        if (sym.getFile(macho_file)) |file| if (file.getIndex() != self.index) continue;
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

pub fn writeSymtab(self: InternalObject, macho_file: *MachO, ctx: anytype) void {
    for (self.symbols.items) |sym_index| {
        const sym = macho_file.getSymbol(sym_index);
        if (sym.getFile(macho_file)) |file| if (file.getIndex() != self.index) continue;
        const idx = sym.getOutputSymtabIndex(macho_file) orelse continue;
        const n_strx = @as(u32, @intCast(ctx.strtab.items.len));
        ctx.strtab.appendSliceAssumeCapacity(sym.getName(macho_file));
        ctx.strtab.appendAssumeCapacity(0);
        const out_sym = &ctx.symtab.items[idx];
        out_sym.n_strx = n_strx;
        sym.setOutputSym(macho_file, out_sym);
    }
}

fn addSection(self: *InternalObject, allocator: Allocator, segname: []const u8, sectname: []const u8) !u32 {
    const n_sect = @as(u32, @intCast(try self.sections.addOne(allocator)));
    self.sections.set(n_sect, .{
        .header = .{
            .sectname = MachO.makeStaticString(sectname),
            .segname = MachO.makeStaticString(segname),
        },
    });
    return n_sect;
}

fn getSectionData(self: *const InternalObject, index: u32) error{Overflow}![]const u8 {
    const slice = self.sections.slice();
    assert(index < slice.items(.header).len);
    const sect = slice.items(.header)[index];
    const extra = slice.items(.extra)[index];
    if (extra.is_objc_methname) {
        const size = std.math.cast(usize, sect.size) orelse return error.Overflow;
        return self.objc_methnames.items[sect.offset..][0..size];
    } else if (extra.is_objc_selref)
        return &self.objc_selrefs
    else
        @panic("ref to non-existent section");
}

pub fn getAtomData(self: *const InternalObject, atom: Atom, buffer: []u8) error{Overflow}!void {
    assert(buffer.len == atom.size);
    const data = try self.getSectionData(atom.n_sect);
    const off = std.math.cast(usize, atom.off) orelse return error.Overflow;
    const size = std.math.cast(usize, atom.size) orelse return error.Overflow;
    @memcpy(buffer, data[off..][0..size]);
}

pub fn getAtomRelocs(self: *const InternalObject, atom: Atom, macho_file: *MachO) []const Relocation {
    if (!atom.flags.relocs) return &[0]Relocation{};
    const extra = atom.getExtra(macho_file).?;
    const relocs = self.sections.items(.relocs)[atom.n_sect];
    return relocs.items[extra.rel_index..][0..extra.rel_count];
}

pub fn getString(self: InternalObject, off: u32) [:0]const u8 {
    _ = self;
    _ = off;
    // We don't have any local strings for synthetic atoms.
    return "";
}

pub fn asFile(self: *InternalObject) File {
    return .{ .internal = self };
}

const FormatContext = struct {
    self: *InternalObject,
    macho_file: *MachO,
};

pub fn fmtAtoms(self: *InternalObject, macho_file: *MachO) std.fmt.Formatter(formatAtoms) {
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
        const atom = ctx.macho_file.getAtom(atom_index).?;
        try writer.print("    {}\n", .{atom.fmt(ctx.macho_file)});
    }
}

pub fn fmtSymtab(self: *InternalObject, macho_file: *MachO) std.fmt.Formatter(formatSymtab) {
    return .{ .data = .{
        .self = self,
        .macho_file = macho_file,
    } };
}

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
        const global = ctx.macho_file.getSymbol(index);
        try writer.print("    {}\n", .{global.fmt(ctx.macho_file)});
    }
}

const Section = struct {
    header: macho.section_64,
    relocs: std.ArrayListUnmanaged(Relocation) = .{},
    extra: Extra = .{},

    const Extra = packed struct {
        is_objc_methname: bool = false,
        is_objc_selref: bool = false,
    };
};

const assert = std.debug.assert;
const macho = std.macho;
const mem = std.mem;
const std = @import("std");

const Allocator = std.mem.Allocator;
const Atom = @import("Atom.zig");
const File = @import("file.zig").File;
const InternalObject = @This();
const MachO = @import("../MachO.zig");
const Object = @import("Object.zig");
const Relocation = @import("Relocation.zig");
const Symbol = @import("Symbol.zig");
