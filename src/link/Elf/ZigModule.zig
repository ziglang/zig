index: File.Index,
elf_locals: std.ArrayListUnmanaged(elf.Elf64_Sym) = .{},
locals: std.ArrayListUnmanaged(Symbol.Index) = .{},
elf_globals: std.ArrayListUnmanaged(elf.Elf64_Sym) = .{},
globals: std.ArrayListUnmanaged(Symbol.Index) = .{},
alive: bool = true,

// output_symtab_size: Elf.SymtabSize = .{},

pub fn deinit(self: *ZigModule, allocator: Allocator) void {
    self.elf_locals.deinit(allocator);
    self.locals.deinit(allocator);
    self.elf_globals.deinit(allocator);
    self.globals.deinit(allocator);
}

pub fn asFile(self: *ZigModule) File {
    return .{ .zig_module = self };
}

pub fn getLocals(self: *ZigModule) []const Symbol.Index {
    return self.locals.items;
}

pub fn getGlobals(self: *ZigModule) []const Symbol.Index {
    return self.globals.items;
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
    for (ctx.self.getLocals()) |index| {
        const local = ctx.elf_file.symbol(index);
        try writer.print("    {}\n", .{local.fmt(ctx.elf_file)});
    }
    try writer.writeAll("  globals\n");
    for (ctx.self.getGlobals()) |index| {
        const global = ctx.elf_file.getSymbol(index);
        try writer.print("    {}\n", .{global.fmt(ctx.elf_file)});
    }
}

const std = @import("std");
const elf = std.elf;

const Allocator = std.mem.Allocator;
const Elf = @import("../Elf.zig");
const File = @import("file.zig").File;
const ZigModule = @This();
// const Object = @import("Object.zig");
const Symbol = @import("Symbol.zig");
