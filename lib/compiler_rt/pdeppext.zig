const std = @import("std");
const builtin = @import("builtin");
const common = @import("common.zig");

const Limb = u32;
const Log2Limb = u5;

comptime {
    @export(__pdep_bigint, .{ .name = "__pdep_bigint", .linkage = common.linkage, .visibility = common.visibility });
    @export(__pdep_u32, .{ .name = "__pdep_u32", .linkage = common.linkage, .visibility = common.visibility });
    @export(__pdep_u64, .{ .name = "__pdep_u64", .linkage = common.linkage, .visibility = common.visibility });
    @export(__pdep_u128, .{ .name = "__pdep_u128", .linkage = common.linkage, .visibility = common.visibility });

    @export(__pext_bigint, .{ .name = "__pext_bigint", .linkage = common.linkage, .visibility = common.visibility });
    @export(__pext_u32, .{ .name = "__pext_u32", .linkage = common.linkage, .visibility = common.visibility });
    @export(__pext_u64, .{ .name = "__pext_u64", .linkage = common.linkage, .visibility = common.visibility });
    @export(__pext_u128, .{ .name = "__pext_u128", .linkage = common.linkage, .visibility = common.visibility });
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

inline fn pdep_bigint(result: []Limb, source: []const Limb, mask: []const Limb) void {
    @memset(result, 0);

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

pub fn __pdep_bigint(r: [*]Limb, s: [*]const Limb, m: [*]const Limb, bits: usize) callconv(.C) void {
    const result = r[0 .. std.math.divCeil(usize, bits, 32) catch unreachable];
    const source = s[0 .. std.math.divCeil(usize, bits, 32) catch unreachable];
    const mask = m[0 .. std.math.divCeil(usize, bits, 32) catch unreachable];

    pdep_bigint(result, source, mask);
}

inline fn pext_bigint(result: []Limb, source: []const Limb, mask: []const Limb) void {
    @memset(result, 0);

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

pub fn __pext_bigint(r: [*]Limb, s: [*]const Limb, m: [*]const Limb, bits: usize) callconv(.C) void {
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

pub fn __pdep_u32(source: u32, mask: u32) callconv(.C) u32 {
    return pdep_uX(u32, source, mask);
}

pub fn __pdep_u64(source: u64, mask: u64) callconv(.C) u64 {
    return pdep_uX(u64, source, mask);
}

pub fn __pdep_u128(source: u128, mask: u128) callconv(.C) u128 {
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

pub fn __pext_u32(source: u32, mask: u32) callconv(.C) u32 {
    return pext_uX(u32, source, mask);
}

pub fn __pext_u64(source: u64, mask: u64) callconv(.C) u64 {
    return pext_uX(u64, source, mask);
}

pub fn __pext_u128(source: u128, mask: u128) callconv(.C) u128 {
    return pext_uX(u128, source, mask);
}
