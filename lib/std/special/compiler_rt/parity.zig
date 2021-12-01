const std = @import("std");
const builtin = @import("builtin");

// parity - if number of bits set is even => 0, else => 1
// - pariytXi2_generic for big and little endian

fn parityXi2_generic(comptime T: type) fn (a: T) callconv(.C) i32 {
    return struct {
        fn f(a: T) callconv(.C) i32 {
            @setRuntimeSafety(builtin.is_test);

            var x = switch (@bitSizeOf(T)) {
                32 => @bitCast(u32, a),
                64 => @bitCast(u64, a),
                128 => @bitCast(u128, a),
                else => unreachable,
            };
            // Bit Twiddling Hacks: Compute parity in parallel
            comptime var shift: u8 = @bitSizeOf(T) / 2;
            inline while (shift > 2) {
                x ^= x >> shift;
                shift = shift >> 1;
            }
            x &= 0xf;
            return (@intCast(u16, 0x6996) >> @intCast(u4, x)) & 1; // optimization for >>2 and >>1
        }
    }.f;
}

pub const __paritysi2 = parityXi2_generic(i32);

pub const __paritydi2 = parityXi2_generic(i64);

pub const __parityti2 = parityXi2_generic(i128);

test {
    _ = @import("paritysi2_test.zig");
    _ = @import("paritydi2_test.zig");
    _ = @import("parityti2_test.zig");
}
