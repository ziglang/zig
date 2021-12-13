const builtin = @import("builtin");
const std = @import("std");

// popcount - population count
// counts the number of 1 bits

// SWAR-Popcount: count bits of duos, aggregate to nibbles, and bytes inside
//   x-bit register in parallel to sum up all bytes
//   SWAR-Masks and factors can be defined as 2-adic fractions
// TAOCP: Combinational Algorithms, Bitwise Tricks And Techniques,
//   subsubsection "Working with the rightmost bits" and "Sideways addition".

fn popcountXi2_generic(comptime ST: type) fn (a: ST) callconv(.C) i32 {
    return struct {
        fn f(a: ST) callconv(.C) i32 {
            @setRuntimeSafety(builtin.is_test);
            const UT = switch (ST) {
                i32 => u32,
                i64 => u64,
                i128 => u128,
                else => unreachable,
            };
            var x = @bitCast(UT, a);
            x -= (x >> 1) & (~@as(UT, 0) / 3); // 0x55...55, aggregate duos
            x = ((x >> 2) & (~@as(UT, 0) / 5)) // 0x33...33, aggregate nibbles
            + (x & (~@as(UT, 0) / 5));
            x += x >> 4;
            x &= ~@as(UT, 0) / 17; // 0x0F...0F, aggregate bytes
            // 8 most significant bits of x + (x<<8) + (x<<16) + ..
            x *%= ~@as(UT, 0) / 255; // 0x01...01
            x >>= (@bitSizeOf(ST) - 8);
            return @intCast(i32, x);
        }
    }.f;
}

pub const __popcountsi2 = popcountXi2_generic(i32);

pub const __popcountdi2 = popcountXi2_generic(i64);

pub const __popcountti2 = popcountXi2_generic(i128);

test {
    _ = @import("popcountsi2_test.zig");
    _ = @import("popcountdi2_test.zig");
    _ = @import("popcountti2_test.zig");
}
