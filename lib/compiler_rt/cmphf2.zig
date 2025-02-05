///! The quoted behavior definitions are from
///! https://gcc.gnu.org/onlinedocs/gcc-12.1.0/gccint/Soft-float-library-routines.html#Soft-float-library-routines
const common = @import("./common.zig");
const comparef = @import("./comparef.zig");

pub const panic = common.panic;

comptime {
    @export(&__eqhf2, .{ .name = "__eqhf2", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__nehf2, .{ .name = "__nehf2", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__lehf2, .{ .name = "__lehf2", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__cmphf2, .{ .name = "__cmphf2", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__lthf2, .{ .name = "__lthf2", .linkage = common.linkage, .visibility = common.visibility });
}

/// "These functions calculate a <=> b. That is, if a is less than b, they return -1;
/// if a is greater than b, they return 1; and if a and b are equal they return 0.
/// If either argument is NaN they return 1..."
///
/// Note that this matches the definition of `__lehf2`, `__eqhf2`, `__nehf2`, `__cmphf2`,
/// and `__lthf2`.
fn __cmphf2(a: f16, b: f16) callconv(.C) i32 {
    return @intFromEnum(comparef.cmpf2(f16, comparef.LE, a, b));
}

/// "These functions return a value less than or equal to zero if neither argument is NaN,
/// and a is less than or equal to b."
pub fn __lehf2(a: f16, b: f16) callconv(.C) i32 {
    return __cmphf2(a, b);
}

/// "These functions return zero if neither argument is NaN, and a and b are equal."
/// Note that due to some kind of historical accident, __eqhf2 and __nehf2 are defined
/// to have the same return value.
pub fn __eqhf2(a: f16, b: f16) callconv(.C) i32 {
    return __cmphf2(a, b);
}

/// "These functions return a nonzero value if either argument is NaN, or if a and b are unequal."
/// Note that due to some kind of historical accident, __eqhf2 and __nehf2 are defined
/// to have the same return value.
pub fn __nehf2(a: f16, b: f16) callconv(.C) i32 {
    return __cmphf2(a, b);
}

/// "These functions return a value less than zero if neither argument is NaN, and a
/// is strictly less than b."
pub fn __lthf2(a: f16, b: f16) callconv(.C) i32 {
    return __cmphf2(a, b);
}
