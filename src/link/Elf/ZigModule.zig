//! ZigModule encapsulates the state of the incrementally compiled Zig module.
//! It stores the associated input local and global symbols, allocated atoms,
//! and any relocations that may have been emitted.
//! Think about this as fake in-memory Object file for the Zig module.

/// Path is owned by Module and lives as long as *Module.
path: []const u8,
index: File.Index,

local_esyms: std.ArrayListUnmanaged(elf.Elf64_Sym) = .{},
global_esyms: std.ArrayListUnmanaged(elf.Elf64_Sym) = .{},
local_symbols: std.ArrayListUnmanaged(Symbol.Index) = .{},
global_symbols: std.ArrayListUnmanaged(Symbol.Index) = .{},
globals_lookup: std.AutoHashMapUnmanaged(u32, Symbol.Index) = .{},

atoms: std.ArrayListUnmanaged(Atom.Index) = .{},
relocs: std.ArrayListUnmanaged(std.ArrayListUnmanaged(elf.Elf64_Rela)) = .{},

output_symtab_size: Elf.SymtabSize = .{},

pub fn deinit(self: *ZigModule, allocator: Allocator) void {
    self.local_esyms.deinit(allocator);
    self.global_esyms.deinit(allocator);
    self.local_symbols.deinit(allocator);
    self.global_symbols.deinit(allocator);
    self.globals_lookup.deinit(allocator);
    self.atoms.deinit(allocator);
    for (self.relocs.items) |*list| {
        list.deinit(allocator);
    }
    self.relocs.deinit(allocator);
}

pub fn addLocalEsym(self: *ZigModule, allocator: Allocator) !Symbol.Index {
    try self.local_esyms.ensureUnusedCapacity(allocator, 1);
    const index = @as(Symbol.Index, @intCast(self.local_esyms.items.len));
    const esym = self.local_esyms.addOneAssumeCapacity();
    esym.* = Elf.null_sym;
    esym.st_info = elf.STB_LOCAL << 4;
    return index;
}

pub fn addGlobalEsym(self: *ZigModule, allocator: Allocator) !Symbol.Index {
    try self.global_esyms.ensureUnusedCapacity(allocator, 1);
    const index = @as(Symbol.Index, @intCast(self.global_esyms.items.len));
    const esym = self.global_esyms.addOneAssumeCapacity();
    esym.* = Elf.null_sym;
    esym.st_info = elf.STB_GLOBAL << 4;
    return index | 0x10000000;
}

pub fn addAtom(self: *ZigModule, elf_file: *Elf) !Symbol.Index {
    const gpa = elf_file.base.allocator;

    const atom_index = try elf_file.addAtom();
    const symbol_index = try elf_file.addSymbol();
    const esym_index = try self.addLocalEsym(gpa);

    const shndx = @as(u16, @intCast(self.atoms.items.len));
    try self.atoms.append(gpa, atom_index);
    try self.local_symbols.append(gpa, symbol_index);

    const atom_ptr = elf_file.atom(atom_index).?;
    atom_ptr.file_index = self.index;

    const symbol_ptr = elf_file.symbol(symbol_index);
    symbol_ptr.file_index = self.index;
    symbol_ptr.atom_index = atom_index;

    const esym = &self.local_esyms.items[esym_index];
    esym.st_shndx = shndx;
    symbol_ptr.esym_index = esym_index;

    const relocs_index = @as(u16, @intCast(self.relocs.items.len));
    const relocs = try self.relocs.addOne(gpa);
    relocs.* = .{};
    atom_ptr.relocs_section_index = relocs_index;

    return symbol_index;
}

pub fn resolveSymbols(self: *ZigModule, elf_file: *Elf) void {
    for (self.globals(), 0..) |index, i| {
        const esym_index = @as(Symbol.Index, @intCast(i)) | 0x10000000;
        const esym = self.global_esyms.items[i];

        if (esym.st_shndx == elf.SHN_UNDEF) continue;

        if (esym.st_shndx != elf.SHN_ABS and esym.st_shndx != elf.SHN_COMMON) {
            const atom_index = self.atoms.items[esym.st_shndx];
            const atom = elf_file.atom(atom_index) orelse continue;
            if (!atom.flags.alive) continue;
        }

        const global = elf_file.symbol(index);
        if (self.asFile().symbolRank(esym, false) < global.symbolRank(elf_file)) {
            const atom_index = switch (esym.st_shndx) {
                elf.SHN_ABS, elf.SHN_COMMON => 0,
                else => self.atoms.items[esym.st_shndx],
            };
            const output_section_index = if (elf_file.atom(atom_index)) |atom|
                atom.outputShndx().?
            else
                elf.SHN_UNDEF;
            global.value = esym.st_value;
            global.atom_index = atom_index;
            global.esym_index = esym_index;
            global.file_index = self.index;
            global.output_section_index = output_section_index;
            global.version_index = elf_file.default_sym_version;
            if (esym.st_bind() == elf.STB_WEAK) global.flags.weak = true;
        }
    }
}

pub fn claimUnresolved(self: *ZigModule, elf_file: *Elf) void {
    for (self.globals(), 0..) |index, i| {
        const esym_index = @as(Symbol.Index, @intCast(i)) | 0x10000000;
        const esym = self.global_esyms.items[i];

        if (esym.st_shndx != elf.SHN_UNDEF) continue;

        const global = elf_file.symbol(index);
        if (global.file(elf_file)) |_| {
            if (global.elfSym(elf_file).st_shndx != elf.SHN_UNDEF) continue;
        }

        const is_import = blk: {
            if (!elf_file.isDynLib()) break :blk false;
            const vis = @as(elf.STV, @enumFromInt(esym.st_other));
            if (vis == .HIDDEN) break :blk false;
            break :blk true;
        };

        global.value = 0;
        global.atom_index = 0;
        global.esym_index = esym_index;
        global.file_index = self.index;
        global.version_index = if (is_import) elf.VER_NDX_LOCAL else elf_file.default_sym_version;
        global.flags.import = is_import;
    }
}

pub fn scanRelocs(self: *ZigModule, elf_file: *Elf, undefs: anytype) !void {
    for (self.atoms.items) |atom_index| {
        const atom = elf_file.atom(atom_index) orelse continue;
        if (!atom.flags.alive) continue;
        if (try atom.scanRelocsRequiresCode(elf_file)) {
            // TODO ideally we don't have to fetch the code here.
            // Perhaps it would make sense to save the code until flushModule where we
            // would free all of generated code?
            const code = try self.codeAlloc(elf_file, atom_index);
            defer elf_file.base.allocator.free(code);
            try atom.scanRelocs(elf_file, code, undefs);
        } else try atom.scanRelocs(elf_file, null, undefs);
    }
}

pub fn resetGlobals(self: *ZigModule, elf_file: *Elf) void {
    for (self.globals()) |index| {
        const global = elf_file.symbol(index);
        const off = global.name_offset;
        global.* = .{};
        global.name_offset = off;
    }
}

pub fn markLive(self: *ZigModule, elf_file: *Elf) void {
    for (self.globals(), 0..) |index, i| {
        const esym = self.global_esyms.items[i];
        if (esym.st_bind() == elf.STB_WEAK) continue;

        const global = elf_file.symbol(index);
        const file = global.file(elf_file) orelse continue;
        const should_keep = esym.st_shndx == elf.SHN_UNDEF or
            (esym.st_shndx == elf.SHN_COMMON and global.elfSym(elf_file).st_shndx != elf.SHN_COMMON);
        if (should_keep and !file.isAlive()) {
            file.setAlive();
            file.markLive(elf_file);
        }
    }
}

pub fn updateSymtabSize(self: *ZigModule, elf_file: *Elf) void {
    for (self.locals()) |local_index| {
        const local = elf_file.symbol(local_index);
        const esym = local.elfSym(elf_file);
        switch (esym.st_type()) {
            elf.STT_SECTION, elf.STT_NOTYPE => {
                local.flags.output_symtab = false;
                continue;
            },
            else => {},
        }
        local.flags.output_symtab = true;
        self.output_symtab_size.nlocals += 1;
    }

    for (self.globals()) |global_index| {
        const global = elf_file.symbol(global_index);
        if (global.file(elf_file)) |file| if (file.index() != self.index) {
            global.flags.output_symtab = false;
            continue;
        };
        global.flags.output_symtab = true;
        if (global.isLocal()) {
            self.output_symtab_size.nlocals += 1;
        } else {
            self.output_symtab_size.nglobals += 1;
        }
    }
}

pub fn writeSymtab(self: *ZigModule, elf_file: *Elf, ctx: anytype) void {
    var ilocal = ctx.ilocal;
    for (self.locals()) |local_index| {
        const local = elf_file.symbol(local_index);
        if (!local.flags.output_symtab) continue;
        local.setOutputSym(elf_file, &ctx.symtab[ilocal]);
        ilocal += 1;
    }

    var iglobal = ctx.iglobal;
    for (self.globals()) |global_index| {
        const global = elf_file.symbol(global_index);
        if (global.file(elf_file)) |file| if (file.index() != self.index) continue;
        if (!global.flags.output_symtab) continue;
        if (global.isLocal()) {
            global.setOutputSym(elf_file, &ctx.symtab[ilocal]);
            ilocal += 1;
        } else {
            global.setOutputSym(elf_file, &ctx.symtab[iglobal]);
            iglobal += 1;
        }
    }
}

pub fn symbol(self: *ZigModule, index: Symbol.Index) Symbol.Index {
    const is_global = index & 0x10000000 != 0;
    const actual_index = index & 0x0fffffff;
    if (is_global) return self.global_symbols.items[actual_index];
    return self.local_symbols.items[actual_index];
}

pub fn elfSym(self: *ZigModule, index: Symbol.Index) *elf.Elf64_Sym {
    const is_global = index & 0x10000000 != 0;
    const actual_index = index & 0x0fffffff;
    if (is_global) return &self.global_esyms.items[actual_index];
    return &self.local_esyms.items[actual_index];
}

pub fn locals(self: *ZigModule) []const Symbol.Index {
    return self.local_symbols.items;
}

pub fn globals(self: *ZigModule) []const Symbol.Index {
    return self.global_symbols.items;
}

pub fn asFile(self: *ZigModule) File {
    return .{ .zig_module = self };
}

/// Returns atom's code.
/// Caller owns the memory.
pub fn codeAlloc(self: ZigModule, elf_file: *Elf, atom_index: Atom.Index) ![]u8 {
    const gpa = elf_file.base.allocator;
    const atom = elf_file.atom(atom_index).?;
    assert(atom.file_index == self.index);
    const shdr = &elf_file.shdrs.items[atom.outputShndx().?];
    const file_offset = shdr.sh_offset + atom.value - shdr.sh_addr;
    const size = std.math.cast(usize, atom.size) orelse return error.Overflow;
    const code = try gpa.alloc(u8, size);
    errdefer gpa.free(code);
    const amt = try elf_file.base.file.?.preadAll(code, file_offset);
    if (amt != code.len) return error.InputOutput;
    return code;
}

pub fn fmtSymtab(self: *ZigModule, elf_file: *Elf) std.fmt.Formatter(formatSymtab) {
    return .{ .data = .{
        .self = self,
        .elf_file = elf_file,
    } };
}

const FormatContext = struct {
    self: *ZigModule,
    elf_file: *Elf,
};

fn formatSymtab(
    ctx: FormatContext,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = unused_fmt_string;
    _ = options;
    try writer.writeAll("  locals\n");
    for (ctx.self.locals()) |index| {
        const local = ctx.elf_file.symbol(index);
        try writer.print("    {}\n", .{local.fmt(ctx.elf_file)});
    }
    try writer.writeAll("  globals\n");
    for (ctx.self.globals()) |index| {
        const global = ctx.elf_file.symbol(index);
        try writer.print("    {}\n", .{global.fmt(ctx.elf_file)});
    }
}

pub fn fmtAtoms(self: *ZigModule, elf_file: *Elf) std.fmt.Formatter(formatAtoms) {
    return .{ .data = .{
        .self = self,
        .elf_file = elf_file,
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
        const atom = ctx.elf_file.atom(atom_index) orelse continue;
        try writer.print("    {}\n", .{atom.fmt(ctx.elf_file)});
    }
}

const assert = std.debug.assert;
const std = @import("std");
const elf = std.elf;

const Allocator = std.mem.Allocator;
const Atom = @import("Atom.zig");
const Elf = @import("../Elf.zig");
const File = @import("file.zig").File;
const Module = @import("../../Module.zig");
const Symbol = @import("Symbol.zig");
const ZigModule = @This();
