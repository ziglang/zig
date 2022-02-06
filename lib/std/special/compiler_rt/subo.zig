const builtin = @import("builtin");

// subo - subtract overflow
// * return a-%b.
// * return if a-b overflows => 1 else => 0
// - suboXi4_generic as default

inline fn suboXi4_generic(comptime ST: type, a: ST, b: ST, overflow: *c_int) ST {
    @setRuntimeSafety(builtin.is_test);
    overflow.* = 0;
    var sum: ST = a -% b;
    // Hackers Delight: section Overflow Detection, subsection Signed Add/Subtract
    // Let sum = a -% b == a - b - carry == wraparound subtraction.
    // Overflow in a-b-carry occurs, iff a and b have opposite signs
    // and the sign of a-b-carry is opposite of a (or equivalently same as b).
    // Faster routine: res = (a ^ b) & (sum ^ a)
    // Slower routine: res = (sum^a) & ~(sum^b)
    // Overflow occured, iff (res < 0)
    if (((a ^ b) & (sum ^ a)) < 0)
        overflow.* = 1;
    return sum;
}

pub fn __subosi4(a: i32, b: i32, overflow: *c_int) callconv(.C) i32 {
    return suboXi4_generic(i32, a, b, overflow);
}
pub fn __subodi4(a: i64, b: i64, overflow: *c_int) callconv(.C) i64 {
    return suboXi4_generic(i64, a, b, overflow);
}
pub fn __suboti4(a: i128, b: i128, overflow: *c_int) callconv(.C) i128 {
    return suboXi4_generic(i128, a, b, overflow);
}

test {
    _ = @import("subosi4_test.zig");
    _ = @import("subodi4_test.zig");
    _ = @import("suboti4_test.zig");
}
