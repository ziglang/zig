const std = @import("std");
const builtin = @import("builtin");
const is_test = builtin.is_test;
const common = @import("./common.zig");
pub const panic = @import("common.zig").panic;

comptime {
    @export(__addosi4, .{ .name = "__addosi4", .linkage = common.linkage, .visibility = common.visibility });
    @export(__addodi4, .{ .name = "__addodi4", .linkage = common.linkage, .visibility = common.visibility });
    @export(__addoti4, .{ .name = "__addoti4", .linkage = common.linkage, .visibility = common.visibility });
}

// addo - add overflow
// * return a+%b.
// * return if a+b overflows => 1 else => 0
// - addoXi4_generic as default

inline fn addoXi4_generic(comptime ST: type, a: ST, b: ST, overflow: *c_int) ST {
    @setRuntimeSafety(builtin.is_test);
    overflow.* = 0;
    var sum: ST = a +% b;
    // Hackers Delight: section Overflow Detection, subsection Signed Add/Subtract
    // Let sum = a +% b == a + b + carry == wraparound addition.
    // Overflow in a+b+carry occurs, iff a and b have opposite signs
    // and the sign of a+b+carry is the same as a (or equivalently b).
    // Slower routine: res = ~(a ^ b) & ((sum ^ a)
    // Faster routine: res = (sum ^ a) & (sum ^ b)
    // Overflow occured, iff (res < 0)
    if (((sum ^ a) & (sum ^ b)) < 0)
        overflow.* = 1;
    return sum;
}

pub fn __addosi4(a: i32, b: i32, overflow: *c_int) callconv(.C) i32 {
    return addoXi4_generic(i32, a, b, overflow);
}
pub fn __addodi4(a: i64, b: i64, overflow: *c_int) callconv(.C) i64 {
    return addoXi4_generic(i64, a, b, overflow);
}
pub fn __addoti4(a: i128, b: i128, overflow: *c_int) callconv(.C) i128 {
    return addoXi4_generic(i128, a, b, overflow);
}

test {
    _ = @import("addosi4_test.zig");
    _ = @import("addodi4_test.zig");
    _ = @import("addoti4_test.zig");
}
