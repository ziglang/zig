const std = @import("std");
const builtin = @import("builtin");
const is_test = builtin.is_test;
const linkage: std.builtin.GlobalLinkage = if (builtin.is_test) .Internal else .Weak;
pub const panic = @import("common.zig").panic;

comptime {
    @export(__addvsi3, .{ .name = "__addvsi3", .linkage = linkage });
    @export(__addvdi3, .{ .name = "__addvdi3", .linkage = linkage });
    @export(__addvti3, .{ .name = "__addvti3", .linkage = linkage });
}

// addv - add overflow
// * return a+%b.
// * return if a+b overflows => 1 else => 0
// - addvXi3_generic as default

inline fn addvXi3_generic(comptime ST: type, a: ST, b: ST) ST {
    @setRuntimeSafety(builtin.is_test);
    var sum: ST = a +% b;
    // Hackers Delight: section Overflow Detection, subsection Signed Add/Subtract
    // Let sum = a +% b == a + b + carry == wraparound addition.
    // Overflow in a+b+carry occurs, iff a and b have opposite signs
    // and the sign of a+b+carry is the same as a (or equivalently b).
    // Slower routine: res = ~(a ^ b) & ((sum ^ a)
    // Faster routine: res = (sum ^ a) & (sum ^ b)
    // Overflow occured, iff (res < 0)
    if (((sum ^ a) & (sum ^ b)) < 0)
        @panic("compiler_rt: addition overflow");
    return sum;
}

pub fn __addvsi3(a: i32, b: i32) callconv(.C) i32 {
    return addvXi3_generic(i32, a, b);
}
pub fn __addvdi3(a: i64, b: i64) callconv(.C) i64 {
    return addvXi3_generic(i64, a, b);
}
pub fn __addvti3(a: i128, b: i128) callconv(.C) i128 {
    return addvXi3_generic(i128, a, b);
}

test {
    _ = @import("addvsi3_test.zig");
    _ = @import("addvdi3_test.zig");
    _ = @import("addvti3_test.zig");
}
