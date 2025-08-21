value: i64 = 0,
output_section_index: u32 = 0,
symbols: std.AutoArrayHashMapUnmanaged(Elf.Ref, void) = .empty,
output_symtab_ctx: Elf.SymtabCtx = .{},

pub fn deinit(thunk: *Thunk, allocator: Allocator) void {
    thunk.symbols.deinit(allocator);
}

pub fn size(thunk: Thunk, elf_file: *Elf) usize {
    const cpu_arch = elf_file.getTarget().cpu.arch;
    return thunk.symbols.keys().len * trampolineSize(cpu_arch);
}

pub fn address(thunk: Thunk, elf_file: *Elf) i64 {
    const shdr = elf_file.sections.items(.shdr)[thunk.output_section_index];
    return @as(i64, @intCast(shdr.sh_addr)) + thunk.value;
}

pub fn targetAddress(thunk: Thunk, ref: Elf.Ref, elf_file: *Elf) i64 {
    const cpu_arch = elf_file.getTarget().cpu.arch;
    return thunk.address(elf_file) + @as(i64, @intCast(thunk.symbols.getIndex(ref).? * trampolineSize(cpu_arch)));
}

pub fn write(thunk: Thunk, elf_file: *Elf, writer: anytype) !void {
    switch (elf_file.getTarget().cpu.arch) {
        .aarch64 => try aarch64.write(thunk, elf_file, writer),
        .x86_64, .riscv64 => unreachable,
        else => @panic("unhandled arch"),
    }
}

pub fn calcSymtabSize(thunk: *Thunk, elf_file: *Elf) void {
    thunk.output_symtab_ctx.nlocals = @as(u32, @intCast(thunk.symbols.keys().len));
    for (thunk.symbols.keys()) |ref| {
        const sym = elf_file.symbol(ref).?;
        thunk.output_symtab_ctx.strsize += @as(u32, @intCast(sym.name(elf_file).len + "$thunk".len + 1));
    }
}

pub fn writeSymtab(thunk: Thunk, elf_file: *Elf) void {
    const cpu_arch = elf_file.getTarget().cpu.arch;
    for (thunk.symbols.keys(), thunk.output_symtab_ctx.ilocal..) |ref, ilocal| {
        const sym = elf_file.symbol(ref).?;
        const st_name = @as(u32, @intCast(elf_file.strtab.items.len));
        elf_file.strtab.appendSliceAssumeCapacity(sym.name(elf_file));
        elf_file.strtab.appendSliceAssumeCapacity("$thunk");
        elf_file.strtab.appendAssumeCapacity(0);
        elf_file.symtab.items[ilocal] = .{
            .st_name = st_name,
            .st_info = elf.STT_FUNC,
            .st_other = 0,
            .st_shndx = @intCast(thunk.output_section_index),
            .st_value = @intCast(thunk.targetAddress(ref, elf_file)),
            .st_size = trampolineSize(cpu_arch),
        };
    }
}

fn trampolineSize(cpu_arch: std.Target.Cpu.Arch) usize {
    return switch (cpu_arch) {
        .aarch64 => aarch64.trampoline_size,
        .x86_64, .riscv64 => unreachable,
        else => @panic("unhandled arch"),
    };
}

pub fn fmt(thunk: Thunk, elf_file: *Elf) std.fmt.Formatter(Format, Format.default) {
    return .{ .data = .{
        .thunk = thunk,
        .elf_file = elf_file,
    } };
}

const Format = struct {
    thunk: Thunk,
    elf_file: *Elf,

    fn default(f: Format, writer: *std.io.Writer) std.io.Writer.Error!void {
        const thunk = f.thunk;
        const elf_file = f.elf_file;
        try writer.print("@{x} : size({x})\n", .{ thunk.value, thunk.size(elf_file) });
        for (thunk.symbols.keys()) |ref| {
            const sym = elf_file.symbol(ref).?;
            try writer.print("  {f} : {s} : @{x}\n", .{ ref, sym.name(elf_file), sym.value });
        }
    }
};

pub const Index = u32;

const aarch64 = struct {
    fn write(thunk: Thunk, elf_file: *Elf, writer: anytype) !void {
        for (thunk.symbols.keys(), 0..) |ref, i| {
            const sym = elf_file.symbol(ref).?;
            const saddr = thunk.address(elf_file) + @as(i64, @intCast(i * trampoline_size));
            const taddr = sym.address(.{}, elf_file);
            try writer.writeInt(u32, @bitCast(
                util.encoding.Instruction.adrp(.x16, try util.calcNumberOfPages(saddr, taddr) << 12),
            ), .little);
            try writer.writeInt(u32, @bitCast(util.encoding.Instruction.add(
                .x16,
                .x16,
                .{ .immediate = @truncate(@as(u64, @bitCast(taddr))) },
            )), .little);
            try writer.writeInt(u32, @bitCast(util.encoding.Instruction.br(.x16)), .little);
        }
    }

    const trampoline_size = 3 * @sizeOf(u32);

    const util = @import("../aarch64.zig");
};

const assert = std.debug.assert;
const elf = std.elf;
const log = std.log.scoped(.link);
const math = std.math;
const mem = std.mem;
const std = @import("std");

const Allocator = mem.Allocator;
const Atom = @import("Atom.zig");
const Elf = @import("../Elf.zig");
const Symbol = @import("Symbol.zig");

const Thunk = @This();
