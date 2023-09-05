index: File.Index,

elf_local_symbols: std.ArrayListUnmanaged(elf.Elf64_Sym) = .{},
local_symbols: std.AutoArrayHashMapUnmanaged(Symbol.Index, void) = .{},

elf_global_symbols: std.ArrayListUnmanaged(elf.Elf64_Sym) = .{},
global_symbols: std.AutoArrayHashMapUnmanaged(Symbol.Index, void) = .{},

atoms: std.ArrayListUnmanaged(Atom.Index) = .{},

alive: bool = true,

// output_symtab_size: Elf.SymtabSize = .{},

pub fn deinit(self: *ZigModule, allocator: Allocator) void {
    self.elf_local_symbols.deinit(allocator);
    self.local_symbols.deinit(allocator);
    self.elf_global_symbols.deinit(allocator);
    self.global_symbols.deinit(allocator);
    self.atoms.deinit(allocator);
}

pub fn createAtom(self: *ZigModule, output_section_index: u16, elf_file: *Elf) !Symbol.Index {
    const gpa = elf_file.base.allocator;
    const atom_index = try elf_file.addAtom();
    const symbol_index = try elf_file.addSymbol();

    const atom_ptr = elf_file.atom(atom_index);
    atom_ptr.file_index = self.index;
    atom_ptr.output_section_index = output_section_index;

    const symbol_ptr = elf_file.symbol(symbol_index);
    symbol_ptr.file_index = self.index;
    symbol_ptr.atom_index = atom_index;
    symbol_ptr.output_section_index = output_section_index;

    const local_esym = try self.elf_local_symbols.addOne(gpa);
    local_esym.* = .{
        .st_name = 0,
        .st_info = elf.STB_LOCAL << 4,
        .st_other = 0,
        .st_shndx = output_section_index,
        .st_value = 0,
        .st_size = 0,
    };

    try self.atoms.append(gpa, atom_index);
    try self.local_symbols.putNoClobber(gpa, symbol_index, {});

    return symbol_index;
}

pub fn addGlobal(self: *ZigModule, name: [:0]const u8, elf_file: *Elf) !Symbol.Index {
    const gpa = elf_file.base.allocator;
    try self.elf_global_symbols.ensureUnusedCapacity(gpa, 1);
    try self.global_symbols.ensureUnusedCapacity(gpa, 1);
    const off = try elf_file.strtab.insert(gpa, name);
    self.elf_global_symbols.appendAssumeCapacity(.{
        .st_name = off,
        .st_info = elf.STB_GLOBAL << 4,
        .st_other = 0,
        .st_shndx = 0,
        .st_value = 0,
        .st_size = 0,
    });
    const gop = try elf_file.getOrPutGlobal(off);
    self.global_symbols.putAssumeCapacityNoClobber(gop.index, {});
    return gop.index;
}

pub fn sourceSymbol(self: *ZigModule, symbol_index: Symbol.Index) *elf.Elf64_Sym {
    if (self.local_symbols.get(symbol_index)) |_| return &self.elf_local_symbols.items[symbol_index];
    assert(self.global_symbols.get(symbol_index) != null);
    return &self.elf_global_symbols.items[symbol_index];
}

pub fn locals(self: *ZigModule) []const Symbol.Index {
    return self.local_symbols.keys();
}

pub fn globals(self: *ZigModule) []const Symbol.Index {
    return self.global_symbols.keys();
}

pub fn asFile(self: *ZigModule) File {
    return .{ .zig_module = self };
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

const assert = std.debug.assert;
const std = @import("std");
const elf = std.elf;

const Allocator = std.mem.Allocator;
const Atom = @import("Atom.zig");
const Elf = @import("../Elf.zig");
const File = @import("file.zig").File;
const Module = @import("../../Module.zig");
const ZigModule = @This();
// const Object = @import("Object.zig");
const Symbol = @import("Symbol.zig");
