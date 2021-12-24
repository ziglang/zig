const std = @import("std");
const builtin = @import("builtin");

// neg - negate (the number)
// - negXi2_generic for unoptimized little and big endian

// sfffffff = 2^31-1
// two's complement inverting bits and add 1 would result in -INT_MIN == 0
// => -INT_MIN = -2^31 forbidden

// * size optimized builds
// * machines that dont support carry operations

fn negXi2_generic(comptime T: type) fn (a: T) callconv(.C) T {
    return struct {
        fn f(a: T) callconv(.C) T {
            @setRuntimeSafety(builtin.is_test);
            return -a;
        }
    }.f;
}

pub const __negsi2 = negXi2_generic(i32);

pub const __negdi2 = negXi2_generic(i64);

pub const __negti2 = negXi2_generic(i128);

test {
    _ = @import("negsi2_test.zig");
    _ = @import("negdi2_test.zig");
    _ = @import("negti2_test.zig");
}
