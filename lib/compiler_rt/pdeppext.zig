const std = @import("std");
const builtin = @import("builtin");
const common = @import("common.zig");

const Limb = u32;
const Log2Limb = u5;

comptime {
    @export(&__pdep_bigint, .{ .name = "__pdep_bigint", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__pdep_u32, .{ .name = "__pdep_u32", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__pdep_u64, .{ .name = "__pdep_u64", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__pdep_u128, .{ .name = "__pdep_u128", .linkage = common.linkage, .visibility = common.visibility });

    @export(&__pext_bigint, .{ .name = "__pext_bigint", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__pext_u32, .{ .name = "__pext_u32", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__pext_u64, .{ .name = "__pext_u64", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__pext_u128, .{ .name = "__pext_u128", .linkage = common.linkage, .visibility = common.visibility });
}

const endian = builtin.cpu.arch.endian();

inline fn limb(x: []const Limb, i: usize) Limb {
    return if (endian == .little) x[i] else x[x.len - 1 - i];
}

inline fn limb_ptr(x: []Limb, i: usize) *Limb {
    return if (endian == .little) &x[i] else &x[x.len - 1 - i];
}

inline fn limb_set(x: []Limb, i: usize, v: Limb) void {
    if (endian == .little) {
        x[i] = v;
    } else {
        x[x.len - 1 - i] = v;
    }
}

// Code for bigint pdep and pext largely taken from std.math.big.int.depositBits and extractBits

// Assumes that `result` is zeroed.
inline fn pdep_bigint(result: []Limb, source: []const Limb, mask: []const Limb) void {
    var mask_limb: Limb = limb(mask, 0);
    var mask_limb_index: usize = 0;
    var i: usize = 0;

    outer: while (true) : (i += 1) {
        // Find the lowest set bit in mask
        const mask_limb_bit: Log2Limb = limb_bit: while (true) {
            const mask_limb_tz = @ctz(mask_limb);
            if (mask_limb_tz != @bitSizeOf(Limb)) {
                const cast_limb_bit: Log2Limb = @intCast(mask_limb_tz);
                mask_limb ^= @as(Limb, 1) << cast_limb_bit;
                break :limb_bit cast_limb_bit;
            }

            mask_limb_index += 1;
            if (mask_limb_index >= mask.len) break :outer;

            mask_limb = limb(mask, mask_limb_index);
        };

        const i_limb_index = i / 32;
        const i_limb_bit: Log2Limb = @truncate(i);

        if (i_limb_index >= source.len) break;

        const source_bit_set = limb(source, i_limb_index) & (@as(Limb, 1) << i_limb_bit) != 0;

        limb_ptr(result, mask_limb_index).* |= @as(Limb, @intFromBool(source_bit_set)) << mask_limb_bit;
    }
}

pub fn __pdep_bigint(r: [*]Limb, s: [*]const Limb, m: [*]const Limb, bits: usize) callconv(.c) void {
    const result_full = r[0 .. std.math.divCeil(usize, @intCast(intAbiSize(@intCast(bits), builtin.target)), 4) catch unreachable];
    @memset(result_full, 0);

    const result = r[0 .. std.math.divCeil(usize, bits, 32) catch unreachable];
    const source = s[0 .. std.math.divCeil(usize, bits, 32) catch unreachable];
    const mask = m[0 .. std.math.divCeil(usize, bits, 32) catch unreachable];

    pdep_bigint(result, source, mask);
}

// Assumes that `result` is zeroed.
inline fn pext_bigint(result: []Limb, source: []const Limb, mask: []const Limb) void {
    var mask_limb: Limb = limb(mask, 0);
    var mask_limb_index: usize = 0;
    var i: usize = 0;

    outer: while (true) : (i += 1) {
        const mask_limb_bit: Log2Limb = limb_bit: while (true) {
            const mask_limb_tz = @ctz(mask_limb);
            if (mask_limb_tz != @bitSizeOf(Limb)) {
                const cast_limb_bit: Log2Limb = @intCast(mask_limb_tz);
                mask_limb ^= @as(Limb, 1) << cast_limb_bit;
                break :limb_bit cast_limb_bit;
            }

            mask_limb_index += 1;
            if (mask_limb_index >= mask.len) break :outer;

            mask_limb = limb(mask, mask_limb_index);
        };

        const i_limb_index = i / 32;
        const i_limb_bit: Log2Limb = @truncate(i);

        if (i_limb_index >= source.len) break;

        const source_bit_set = limb(source, mask_limb_index) & (@as(Limb, 1) << mask_limb_bit) != 0;

        limb_ptr(result, i_limb_index).* |= @as(Limb, @intFromBool(source_bit_set)) << i_limb_bit;
    }
}

pub fn __pext_bigint(r: [*]Limb, s: [*]const Limb, m: [*]const Limb, bits: usize) callconv(.c) void {
    const result_full = r[0 .. std.math.divCeil(usize, @intCast(intAbiSize(@intCast(bits), builtin.target)), 4) catch unreachable];
    @memset(result_full, 0);

    const result = r[0 .. std.math.divCeil(usize, bits, 32) catch unreachable];
    const source = s[0 .. std.math.divCeil(usize, bits, 32) catch unreachable];
    const mask = m[0 .. std.math.divCeil(usize, bits, 32) catch unreachable];

    pext_bigint(result, source, mask);
}

inline fn pdep_uX(comptime T: type, source: T, mask_: T) T {
    var bb: T = 1;
    var result: T = 0;
    var mask = mask_;

    while (mask != 0) {
        const bit = mask & ~(mask - 1);
        mask &= ~bit;
        const source_bit = source & bb;
        if (source_bit != 0) result |= bit;
        bb += bb;
    }

    return result;
}

pub fn __pdep_u32(source: u32, mask: u32) callconv(.c) u32 {
    return pdep_uX(u32, source, mask);
}

pub fn __pdep_u64(source: u64, mask: u64) callconv(.c) u64 {
    return pdep_uX(u64, source, mask);
}

pub fn __pdep_u128(source: u128, mask: u128) callconv(.c) u128 {
    return pdep_uX(u128, source, mask);
}

inline fn pext_uX(comptime T: type, source: T, mask_: T) T {
    var bb: T = 1;
    var result: T = 0;
    var mask = mask_;

    while (mask != 0) {
        const bit = mask & ~(mask - 1);
        mask &= ~bit;
        const source_bit = source & bit;
        if (source_bit != 0) result |= bb;
        bb += bb;
    }

    return result;
}

pub fn __pext_u32(source: u32, mask: u32) callconv(.c) u32 {
    return pext_uX(u32, source, mask);
}

pub fn __pext_u64(source: u64, mask: u64) callconv(.c) u64 {
    return pext_uX(u64, source, mask);
}

pub fn __pext_u128(source: u128, mask: u128) callconv(.c) u128 {
    return pext_uX(u128, source, mask);
}

// BEGIN HACKY CODE COPY WAIT FOR ALEXRP PR

const Target = std.Target;
const assert = std.debug.assert;

pub const Alignment = enum(u6) {
    @"1" = 0,
    @"2" = 1,
    @"4" = 2,
    @"8" = 3,
    @"16" = 4,
    @"32" = 5,
    @"64" = 6,
    none = std.math.maxInt(u6),
    _,

    pub fn fromByteUnits(n: u64) Alignment {
        if (n == 0) return .none;
        assert(std.math.isPowerOfTwo(n));
        return @enumFromInt(@ctz(n));
    }

    /// Align an address forwards to this alignment.
    pub fn forward(a: Alignment, addr: u64) u64 {
        assert(a != .none);
        const x = (@as(u64, 1) << @intFromEnum(a)) - 1;
        return (addr + x) & ~x;
    }
};

pub fn intAbiSize(bits: u16, target: Target) u64 {
    return intAbiAlignment(bits, target).forward(@as(u16, @intCast((@as(u17, bits) + 7) / 8)));
}

pub fn intAbiAlignment(bits: u16, target: Target) Alignment {
    return switch (target.cpu.arch) {
        .x86 => switch (bits) {
            0 => .none,
            1...8 => .@"1",
            9...16 => .@"2",
            17...32 => .@"4",
            33...64 => switch (target.os.tag) {
                .uefi, .windows => .@"8",
                else => .@"4",
            },
            else => .@"16",
        },
        .x86_64 => switch (bits) {
            0 => .none,
            1...8 => .@"1",
            9...16 => .@"2",
            17...32 => .@"4",
            33...64 => .@"8",
            else => .@"16",
        },
        else => return Alignment.fromByteUnits(@min(
            std.math.ceilPowerOfTwoPromote(u16, @as(u16, @intCast((@as(u17, bits) + 7) / 8))),
            maxIntAlignment(target),
        )),
    };
}

pub fn maxIntAlignment(target: std.Target) u16 {
    return switch (target.cpu.arch) {
        .avr => 1,
        .msp430 => 2,
        .xcore => 4,
        .propeller => 4,

        .arm,
        .armeb,
        .thumb,
        .thumbeb,
        .hexagon,
        .mips,
        .mipsel,
        .powerpc,
        .powerpcle,
        .amdgcn,
        .riscv32,
        .sparc,
        .s390x,
        .lanai,
        .wasm32,
        .wasm64,
        => 8,

        // For these, LLVMABIAlignmentOfType(i128) reports 8. Note that 16
        // is a relevant number in three cases:
        // 1. Different machine code instruction when loading into SIMD register.
        // 2. The C ABI wants 16 for extern structs.
        // 3. 16-byte cmpxchg needs 16-byte alignment.
        // Same logic for powerpc64, mips64, sparc64.
        .powerpc64,
        .powerpc64le,
        .mips64,
        .mips64el,
        .sparc64,
        => switch (target.ofmt) {
            .c => 16,
            else => 8,
        },

        .x86_64 => 16,

        // Even LLVMABIAlignmentOfType(i128) agrees on these targets.
        .x86,
        .aarch64,
        .aarch64_be,
        .riscv64,
        .bpfel,
        .bpfeb,
        .nvptx,
        .nvptx64,
        => 16,

        // Below this comment are unverified but based on the fact that C requires
        // int128_t to be 16 bytes aligned, it's a safe default.
        .csky,
        .arc,
        .m68k,
        .kalimba,
        .spirv,
        .spirv32,
        .ve,
        .spirv64,
        .loongarch32,
        .loongarch64,
        .xtensa,
        => 16,
    };
}
