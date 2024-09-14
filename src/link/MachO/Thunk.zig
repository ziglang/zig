value: u64 = 0,
out_n_sect: u8 = 0,
symbols: std.AutoArrayHashMapUnmanaged(MachO.Ref, void) = .empty,
output_symtab_ctx: MachO.SymtabCtx = .{},

pub fn deinit(thunk: *Thunk, allocator: Allocator) void {
    thunk.symbols.deinit(allocator);
}

pub fn size(thunk: Thunk) usize {
    return thunk.symbols.keys().len * trampoline_size;
}

pub fn getAddress(thunk: Thunk, macho_file: *MachO) u64 {
    const header = macho_file.sections.items(.header)[thunk.out_n_sect];
    return header.addr + thunk.value;
}

pub fn getTargetAddress(thunk: Thunk, ref: MachO.Ref, macho_file: *MachO) u64 {
    return thunk.getAddress(macho_file) + thunk.symbols.getIndex(ref).? * trampoline_size;
}

pub fn write(thunk: Thunk, macho_file: *MachO, writer: anytype) !void {
    for (thunk.symbols.keys(), 0..) |ref, i| {
        const sym = ref.getSymbol(macho_file).?;
        const saddr = thunk.getAddress(macho_file) + i * trampoline_size;
        const taddr = sym.getAddress(.{}, macho_file);
        const pages = try aarch64.calcNumberOfPages(@intCast(saddr), @intCast(taddr));
        try writer.writeInt(u32, aarch64.Instruction.adrp(.x16, pages).toU32(), .little);
        const off: u12 = @truncate(taddr);
        try writer.writeInt(u32, aarch64.Instruction.add(.x16, .x16, off, false).toU32(), .little);
        try writer.writeInt(u32, aarch64.Instruction.br(.x16).toU32(), .little);
    }
}

pub fn calcSymtabSize(thunk: *Thunk, macho_file: *MachO) void {
    thunk.output_symtab_ctx.nlocals = @as(u32, @intCast(thunk.symbols.keys().len));
    for (thunk.symbols.keys()) |ref| {
        const sym = ref.getSymbol(macho_file).?;
        thunk.output_symtab_ctx.strsize += @as(u32, @intCast(sym.getName(macho_file).len + "__thunk".len + 1));
    }
}

pub fn writeSymtab(thunk: Thunk, macho_file: *MachO, ctx: anytype) void {
    var n_strx = thunk.output_symtab_ctx.stroff;
    for (thunk.symbols.keys(), thunk.output_symtab_ctx.ilocal..) |ref, ilocal| {
        const sym = ref.getSymbol(macho_file).?;
        const name = sym.getName(macho_file);
        const out_sym = &ctx.symtab.items[ilocal];
        out_sym.n_strx = n_strx;
        @memcpy(ctx.strtab.items[n_strx..][0..name.len], name);
        n_strx += @intCast(name.len);
        @memcpy(ctx.strtab.items[n_strx..][0.."__thunk".len], "__thunk");
        n_strx += @intCast("__thunk".len);
        ctx.strtab.items[n_strx] = 0;
        n_strx += 1;
        out_sym.n_type = macho.N_SECT;
        out_sym.n_sect = @intCast(thunk.out_n_sect + 1);
        out_sym.n_value = @intCast(thunk.getTargetAddress(ref, macho_file));
        out_sym.n_desc = 0;
    }
}

pub fn format(
    thunk: Thunk,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = thunk;
    _ = unused_fmt_string;
    _ = options;
    _ = writer;
    @compileError("do not format Thunk directly");
}

pub fn fmt(thunk: Thunk, macho_file: *MachO) std.fmt.Formatter(format2) {
    return .{ .data = .{
        .thunk = thunk,
        .macho_file = macho_file,
    } };
}

const FormatContext = struct {
    thunk: Thunk,
    macho_file: *MachO,
};

fn format2(
    ctx: FormatContext,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    _ = unused_fmt_string;
    const thunk = ctx.thunk;
    const macho_file = ctx.macho_file;
    try writer.print("@{x} : size({x})\n", .{ thunk.value, thunk.size() });
    for (thunk.symbols.keys()) |ref| {
        const sym = ref.getSymbol(macho_file).?;
        try writer.print("  {} : {s} : @{x}\n", .{ ref, sym.getName(macho_file), sym.value });
    }
}

const trampoline_size = 3 * @sizeOf(u32);

pub const Index = u32;

const aarch64 = @import("../aarch64.zig");
const assert = std.debug.assert;
const log = std.log.scoped(.link);
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const std = @import("std");
const trace = @import("../../tracy.zig").trace;

const Allocator = mem.Allocator;
const Atom = @import("Atom.zig");
const MachO = @import("../MachO.zig");
const Relocation = @import("Relocation.zig");
const Symbol = @import("Symbol.zig");

const Thunk = @This();
