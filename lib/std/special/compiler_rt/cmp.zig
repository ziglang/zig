const builtin = @import("builtin");

// cmp - signed compare
// - cmpXi2_generic for unoptimized little and big endian

// ucmp - unsigned compare
// - ucmpXi2_generic for unoptimized little and big endian

// a <  b => 0
// a == b => 1
// a >  b => 2

inline fn XcmpXi2(comptime T: type, a: T, b: T) i32 {
    @setRuntimeSafety(builtin.is_test);
    var cmp1: i32 = 0;
    var cmp2: i32 = 0;
    if (a > b)
        cmp1 = 1;
    if (a < b)
        cmp2 = 1;
    return cmp1 - cmp2 + 1;
}

pub fn __cmpsi2(a: i32, b: i32) callconv(.C) i32 {
    return XcmpXi2(i32, a, b);
}

pub fn __cmpdi2(a: i64, b: i64) callconv(.C) i32 {
    return XcmpXi2(i64, a, b);
}

pub fn __cmpti2(a: i128, b: i128) callconv(.C) i32 {
    return XcmpXi2(i128, a, b);
}

pub fn __ucmpsi2(a: u32, b: u32) callconv(.C) i32 {
    return XcmpXi2(u32, a, b);
}

pub fn __ucmpdi2(a: u64, b: u64) callconv(.C) i32 {
    return XcmpXi2(u64, a, b);
}

pub fn __ucmpti2(a: u128, b: u128) callconv(.C) i32 {
    return XcmpXi2(u128, a, b);
}

test {
    _ = @import("cmpsi2_test.zig");
    _ = @import("cmpdi2_test.zig");
    _ = @import("cmpti2_test.zig");

    _ = @import("ucmpsi2_test.zig");
    _ = @import("ucmpdi2_test.zig");
    _ = @import("ucmpti2_test.zig");
}
