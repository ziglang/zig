pub const Kind = enum {
    none,
    other,
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
        fn decode(r_type: u32) Kind {
            inline for (mapping) |entry| {
                if (@intFromEnum(entry[1]) == r_type) return entry[0];
            }
            return .other;
        }

        fn encode(comptime kind: Kind) u32 {
            inline for (mapping) |entry| {
                if (entry[0] == kind) return @intFromEnum(entry[1]);
            }
            @panic("encoding .other is ambiguous");
        }
    };
}

const x86_64_relocs = Table(11, elf.R_X86_64, .{
    .{ .none, .NONE },
    .{ .abs, .@"64" },
    .{ .copy, .COPY },
    .{ .rel, .RELATIVE },
    .{ .irel, .IRELATIVE },
    .{ .glob_dat, .GLOB_DAT },
    .{ .jump_slot, .JUMP_SLOT },
    .{ .dtpmod, .DTPMOD64 },
    .{ .dtpoff, .DTPOFF64 },
    .{ .tpoff, .TPOFF64 },
    .{ .tlsdesc, .TLSDESC },
});

const aarch64_relocs = Table(11, elf.R_AARCH64, .{
    .{ .none, .NONE },
    .{ .abs, .ABS64 },
    .{ .copy, .COPY },
    .{ .rel, .RELATIVE },
    .{ .irel, .IRELATIVE },
    .{ .glob_dat, .GLOB_DAT },
    .{ .jump_slot, .JUMP_SLOT },
    .{ .dtpmod, .TLS_DTPMOD },
    .{ .dtpoff, .TLS_DTPREL },
    .{ .tpoff, .TLS_TPREL },
    .{ .tlsdesc, .TLSDESC },
});

const riscv64_relocs = Table(11, elf.R_RISCV, .{
    .{ .none, .NONE },
    .{ .abs, .@"64" },
    .{ .copy, .COPY },
    .{ .rel, .RELATIVE },
    .{ .irel, .IRELATIVE },
    .{ .glob_dat, .@"64" },
    .{ .jump_slot, .JUMP_SLOT },
    .{ .dtpmod, .TLS_DTPMOD64 },
    .{ .dtpoff, .TLS_DTPREL64 },
    .{ .tpoff, .TLS_TPREL64 },
    .{ .tlsdesc, .TLSDESC },
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

pub const dwarf = struct {
    pub fn crossSectionRelocType(format: DW.Format, cpu_arch: std.Target.Cpu.Arch) u32 {
        return switch (cpu_arch) {
            .x86_64 => @intFromEnum(switch (format) {
                .@"32" => elf.R_X86_64.@"32",
                .@"64" => .@"64",
            }),
            .riscv64 => @intFromEnum(switch (format) {
                .@"32" => elf.R_RISCV.@"32",
                .@"64" => .@"64",
            }),
            else => @panic("TODO unhandled cpu arch"),
        };
    }

    pub fn externalRelocType(
        target: Symbol,
        source_section: Dwarf.Section.Index,
        address_size: Dwarf.AddressSize,
        cpu_arch: std.Target.Cpu.Arch,
    ) u32 {
        return switch (cpu_arch) {
            .x86_64 => @intFromEnum(@as(elf.R_X86_64, switch (source_section) {
                else => switch (address_size) {
                    .@"32" => if (target.flags.is_tls) .DTPOFF32 else .@"32",
                    .@"64" => if (target.flags.is_tls) .DTPOFF64 else .@"64",
                    else => unreachable,
                },
                .debug_frame => .PC32,
            })),
            .riscv64 => @intFromEnum(@as(elf.R_RISCV, switch (source_section) {
                else => switch (address_size) {
                    .@"32" => .@"32",
                    .@"64" => .@"64",
                    else => unreachable,
                },
                .debug_frame => unreachable,
            })),
            else => @panic("TODO unhandled cpu arch"),
        };
    }

    const DW = std.dwarf;
};

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
    switch (ctx.cpu_arch) {
        .x86_64 => try writer.print("R_X86_64_{s}", .{@tagName(@as(elf.R_X86_64, @enumFromInt(r_type)))}),
        .aarch64 => try writer.print("R_AARCH64_{s}", .{@tagName(@as(elf.R_AARCH64, @enumFromInt(r_type)))}),
        .riscv64 => try writer.print("R_RISCV_{s}", .{@tagName(@as(elf.R_RISCV, @enumFromInt(r_type)))}),
        else => unreachable,
    }
}

const assert = std.debug.assert;
const elf = std.elf;
const std = @import("std");

const Dwarf = @import("../Dwarf.zig");
const Elf = @import("../Elf.zig");
const Symbol = @import("Symbol.zig");
