pub const Kind = enum {
    abs,
    copy,
    rel,
    irel,
    glob_dat,
    jump_slot,
    dtpmod,
    dtpoff,
    tpoff,
    tlsdesc,
};

fn Table(comptime len: comptime_int, comptime RelType: type, comptime mapping: [len]struct { Kind, RelType }) type {
    return struct {
        fn decode(r_type: u32) ?Kind {
            inline for (mapping) |entry| {
                if (@intFromEnum(entry[1]) == r_type) return entry[0];
            }
            return null;
        }

        fn encode(comptime kind: Kind) u32 {
            inline for (mapping) |entry| {
                if (entry[0] == kind) return @intFromEnum(entry[1]);
            }
            unreachable;
        }
    };
}

const x86_64_relocs = Table(10, elf.R_X86_64, .{
    .{ .abs, .R_X86_64_64 },
    .{ .copy, .R_X86_64_COPY },
    .{ .rel, .R_X86_64_RELATIVE },
    .{ .irel, .R_X86_64_IRELATIVE },
    .{ .glob_dat, .R_X86_64_GLOB_DAT },
    .{ .jump_slot, .R_X86_64_JUMP_SLOT },
    .{ .dtpmod, .R_X86_64_DTPMOD64 },
    .{ .dtpoff, .R_X86_64_DTPOFF64 },
    .{ .tpoff, .R_X86_64_TPOFF64 },
    .{ .tlsdesc, .R_X86_64_TLSDESC },
});

const aarch64_relocs = Table(10, elf.R_AARCH64, .{
    .{ .abs, .R_AARCH64_ABS64 },
    .{ .copy, .R_AARCH64_COPY },
    .{ .rel, .R_AARCH64_RELATIVE },
    .{ .irel, .R_AARCH64_IRELATIVE },
    .{ .glob_dat, .R_AARCH64_GLOB_DAT },
    .{ .jump_slot, .R_AARCH64_JUMP_SLOT },
    .{ .dtpmod, .R_AARCH64_TLS_DTPMOD },
    .{ .dtpoff, .R_AARCH64_TLS_DTPREL },
    .{ .tpoff, .R_AARCH64_TLS_TPREL },
    .{ .tlsdesc, .R_AARCH64_TLSDESC },
});

const riscv64_relocs = Table(9, elf.R_RISCV, .{
    .{ .abs, .R_RISCV_64 },
    .{ .copy, .R_RISCV_COPY },
    .{ .rel, .R_RISCV_RELATIVE },
    .{ .irel, .R_RISCV_IRELATIVE },
    .{ .jump_slot, .R_RISCV_JUMP_SLOT },
    .{ .dtpmod, .R_RISCV_TLS_DTPMOD64 },
    .{ .dtpoff, .R_RISCV_TLS_DTPREL64 },
    .{ .tpoff, .R_RISCV_TLS_TPREL64 },
    .{ .tlsdesc, .R_RISCV_TLSDESC },
});

pub fn decode(r_type: u32, cpu_arch: std.Target.Cpu.Arch) ?Kind {
    return switch (cpu_arch) {
        .x86_64 => x86_64_relocs.decode(r_type),
        .aarch64 => aarch64_relocs.decode(r_type),
        .riscv64 => riscv64_relocs.decode(r_type),
        else => @panic("TODO unhandled cpu arch"),
    };
}

pub fn encode(comptime kind: Kind, cpu_arch: std.Target.Cpu.Arch) u32 {
    return switch (cpu_arch) {
        .x86_64 => x86_64_relocs.encode(kind),
        .aarch64 => aarch64_relocs.encode(kind),
        .riscv64 => riscv64_relocs.encode(kind),
        else => @panic("TODO unhandled cpu arch"),
    };
}

const FormatRelocTypeCtx = struct {
    r_type: u32,
    cpu_arch: std.Target.Cpu.Arch,
};

pub fn fmtRelocType(r_type: u32, cpu_arch: std.Target.Cpu.Arch) std.fmt.Formatter(formatRelocType) {
    return .{ .data = .{
        .r_type = r_type,
        .cpu_arch = cpu_arch,
    } };
}

fn formatRelocType(
    ctx: FormatRelocTypeCtx,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = unused_fmt_string;
    _ = options;
    const r_type = ctx.r_type;
    const str = switch (r_type) {
        Elf.R_ZIG_GOT32 => "R_ZIG_GOT32",
        Elf.R_ZIG_GOTPCREL => "R_ZIG_GOTPCREL",
        else => switch (ctx.cpu_arch) {
            .x86_64 => @tagName(@as(elf.R_X86_64, @enumFromInt(r_type))),
            .aarch64 => @tagName(@as(elf.R_AARCH64, @enumFromInt(r_type))),
            .riscv64 => @tagName(@as(elf.R_RISCV, @enumFromInt(r_type))),
            else => unreachable,
        },
    };
    try writer.print("{s}", .{str});
}

const assert = std.debug.assert;
const elf = std.elf;
const std = @import("std");

const Elf = @import("../Elf.zig");
