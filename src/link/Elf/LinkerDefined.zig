index: File.Index,
symtab: std.ArrayListUnmanaged(elf.Elf64_Sym) = .{},
symbols: std.ArrayListUnmanaged(Symbol.Index) = .{},

output_symtab_size: Elf.SymtabSize = .{},

pub fn deinit(self: *LinkerDefined, allocator: Allocator) void {
    self.symtab.deinit(allocator);
    self.symbols.deinit(allocator);
}

pub fn addGlobal(self: *LinkerDefined, name: [:0]const u8, elf_file: *Elf) !u32 {
    const gpa = elf_file.base.allocator;
    try self.symtab.ensureUnusedCapacity(gpa, 1);
    try self.symbols.ensureUnusedCapacity(gpa, 1);
    self.symtab.appendAssumeCapacity(.{
        .st_name = try elf_file.strtab.insert(gpa, name),
        .st_info = elf.STB_GLOBAL << 4,
        .st_other = @intFromEnum(elf.STV.HIDDEN),
        .st_shndx = elf.SHN_ABS,
        .st_value = 0,
        .st_size = 0,
    });
    const off = try elf_file.strtab.insert(gpa, name);
    const gop = try elf_file.getOrPutGlobal(off);
    self.symbols.addOneAssumeCapacity().* = gop.index;
    return gop.index;
}

pub fn resolveSymbols(self: *LinkerDefined, elf_file: *Elf) void {
    for (self.symbols.items, 0..) |index, i| {
        const sym_idx = @as(Symbol.Index, @intCast(i));
        const this_sym = self.symtab.items[sym_idx];

        if (this_sym.st_shndx == elf.SHN_UNDEF) continue;

        const global = elf_file.symbol(index);
        if (self.asFile().symbolRank(this_sym, false) < global.symbolRank(elf_file)) {
            global.value = 0;
            global.name_offset = global.name_offset;
            global.atom_index = 0;
            global.file_index = self.index;
            global.esym_index = sym_idx;
            global.version_index = elf_file.default_sym_version;
        }
    }
}

pub fn updateSymtabSize(self: *LinkerDefined, elf_file: *Elf) void {
    for (self.globals()) |global_index| {
        const global = elf_file.symbol(global_index);
        if (global.file(elf_file)) |file| if (file.index() != self.index) continue;
        global.flags.output_symtab = true;
        self.output_symtab_size.nlocals += 1;
    }
}

pub fn writeSymtab(self: *LinkerDefined, elf_file: *Elf, ctx: anytype) void {
    var ilocal = ctx.ilocal;
    for (self.globals()) |global_index| {
        const global = elf_file.symbol(global_index);
        if (global.file(elf_file)) |file| if (file.index() != self.index) continue;
        if (!global.flags.output_symtab) continue;
        global.setOutputSym(elf_file, &ctx.symtab[ilocal]);
        ilocal += 1;
    }
}

pub fn globals(self: *LinkerDefined) []const Symbol.Index {
    return self.symbols.items;
}

pub fn asFile(self: *LinkerDefined) File {
    return .{ .linker_defined = self };
}

pub fn fmtSymtab(self: *LinkerDefined, elf_file: *Elf) std.fmt.Formatter(formatSymtab) {
    return .{ .data = .{
        .self = self,
        .elf_file = elf_file,
    } };
}

const FormatContext = struct {
    self: *LinkerDefined,
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
    try writer.writeAll("  globals\n");
    for (ctx.self.globals()) |index| {
        const global = ctx.elf_file.symbol(index);
        try writer.print("    {}\n", .{global.fmt(ctx.elf_file)});
    }
}

const std = @import("std");
const elf = std.elf;

const Allocator = std.mem.Allocator;
const Elf = @import("../Elf.zig");
const File = @import("file.zig").File;
const LinkerDefined = @This();
// const Object = @import("Object.zig");
const Symbol = @import("Symbol.zig");
