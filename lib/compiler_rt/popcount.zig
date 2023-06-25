//! popcount - population count
//! counts the number of 1 bits
//! SWAR-Popcount: count bits of duos, aggregate to nibbles, and bytes inside
//!   x-bit register in parallel to sum up all bytes
//!   SWAR-Masks and factors can be defined as 2-adic fractions
//! TAOCP: Combinational Algorithms, Bitwise Tricks And Techniques,
//!   subsubsection "Working with the rightmost bits" and "Sideways addition".

const builtin = @import("builtin");
const std = @import("std");
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    @export(__popcountsi2, .{ .name = "__popcountsi2", .linkage = common.linkage, .visibility = common.visibility });
    @export(__popcountdi2, .{ .name = "__popcountdi2", .linkage = common.linkage, .visibility = common.visibility });
    @export(__popcountti2, .{ .name = "__popcountti2", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __popcountsi2(a: i32) callconv(.C) i32 {
    return popcountXi2(i32, a);
}

pub fn __popcountdi2(a: i64) callconv(.C) i32 {
    return popcountXi2(i64, a);
}

pub fn __popcountti2(a: i128) callconv(.C) i32 {
    return popcountXi2(i128, a);
}

inline fn popcountXi2(comptime ST: type, a: ST) i32 {
    const UT = switch (ST) {
        i32 => u32,
        i64 => u64,
        i128 => u128,
        else => unreachable,
    };
    var x = @as(UT, @bitCast(a));
    x -= (x >> 1) & (~@as(UT, 0) / 3); // 0x55...55, aggregate duos
    x = ((x >> 2) & (~@as(UT, 0) / 5)) // 0x33...33, aggregate nibbles
    + (x & (~@as(UT, 0) / 5));
    x += x >> 4;
    x &= ~@as(UT, 0) / 17; // 0x0F...0F, aggregate bytes
    // 8 most significant bits of x + (x<<8) + (x<<16) + ..
    x *%= ~@as(UT, 0) / 255; // 0x01...01
    x >>= (@bitSizeOf(ST) - 8);
    return @as(i32, @intCast(x));
}

test {
    _ = @import("popcountsi2_test.zig");
    _ = @import("popcountdi2_test.zig");
    _ = @import("popcountti2_test.zig");
}
