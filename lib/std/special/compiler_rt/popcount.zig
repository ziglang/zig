const builtin = @import("builtin");
const std = @import("std");

// popcount - population count
// counts the number of 1 bits

// SWAR-Popcount: count bits of duos, aggregate to nibbles, and bytes inside
//   x-bit register in parallel to sum up all bytes
//   SWAR-Masks and factors can be defined as 2-adic fractions
// TAOCP: Combinational Algorithms, Bitwise Tricks And Techniques,
//   subsubsection "Working with the rightmost bits" and "Sideways addition".
fn popcountXi2_generic(comptime T: type) fn (a: T) callconv(.C) i32 {
    return struct {
        fn f(a: T) callconv(.C) i32 {
            @setRuntimeSafety(builtin.is_test);

            var x = switch (@bitSizeOf(T)) {
                32 => @bitCast(u32, a),
                64 => @bitCast(u64, a),
                128 => @bitCast(u128, a),
                else => unreachable,
            };
            const k1 = switch (@bitSizeOf(T)) { // -1/3
                32 => @as(u32, 0x55555555),
                64 => @as(u64, 0x55555555_55555555),
                128 => @as(u128, 0x55555555_55555555_55555555_55555555),
                else => unreachable,
            };
            const k2 = switch (@bitSizeOf(T)) { // -1/5
                32 => @as(u32, 0x33333333),
                64 => @as(u64, 0x33333333_33333333),
                128 => @as(u128, 0x33333333_33333333_33333333_33333333),
                else => unreachable,
            };
            const k4 = switch (@bitSizeOf(T)) { // -1/17
                32 => @as(u32, 0x0f0f0f0f),
                64 => @as(u64, 0x0f0f0f0f_0f0f0f0f),
                128 => @as(u128, 0x0f0f0f0f_0f0f0f0f_0f0f0f0f_0f0f0f0f),
                else => unreachable,
            };
            const kf = switch (@bitSizeOf(T)) { // -1/255
                32 => @as(u32, 0x01010101),
                64 => @as(u64, 0x01010101_01010101),
                128 => @as(u128, 0x01010101_01010101_01010101_01010101),
                else => unreachable,
            };
            x = x - ((x >> 1) & k1); // aggregate duos
            x = (x & k2) + ((x >> 2) & k2); // aggregate nibbles
            x = (x + (x >> 4)) & k4; // aggregate bytes
            x = (x *% kf) >> @bitSizeOf(T) - 8; // 8 most significant bits of x + (x<<8) + (x<<16) + ..
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
