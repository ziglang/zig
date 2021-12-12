const std = @import("std");
const builtin = @import("builtin");

// cmp - signed compare
// - cmpXi2_generic for unoptimized little and big endian

// ucmp - unsigned compare
// - ucmpXi2_generic for unoptimized little and big endian

// a <  b => 0
// a == b => 1
// a >  b => 2

fn XcmpXi2_generic(comptime T: type) fn (a: T, b: T) callconv(.C) i32 {
    return struct {
        fn f(a: T, b: T) callconv(.C) i32 {
            @setRuntimeSafety(builtin.is_test);
            var cmp1: i32 = 0;
            var cmp2: i32 = 0;
            if (a > b)
                cmp1 = 1;
            if (a < b)
                cmp2 = 1;
            return cmp1 - cmp2 + 1;
        }
    }.f;
}

pub const __cmpsi2 = XcmpXi2_generic(i32);
pub const __cmpdi2 = XcmpXi2_generic(i64);
pub const __cmpti2 = XcmpXi2_generic(i128);

pub const __ucmpsi2 = XcmpXi2_generic(u32);
pub const __ucmpdi2 = XcmpXi2_generic(u64);
pub const __ucmpti2 = XcmpXi2_generic(u128);

test {
    _ = @import("cmpsi2_test.zig");
    _ = @import("cmpdi2_test.zig");
    _ = @import("cmpti2_test.zig");

    _ = @import("ucmpsi2_test.zig");
    _ = @import("ucmpdi2_test.zig");
    _ = @import("ucmpti2_test.zig");
}
