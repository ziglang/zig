///! The quoted behavior definitions are from
///! https://gcc.gnu.org/onlinedocs/gcc-12.1.0/gccint/Soft-float-library-routines.html#Soft-float-library-routines
const common = @import("./common.zig");
const comparef = @import("./comparef.zig");

pub const panic = common.panic;

comptime {
    @export(__eqxf2, .{ .name = "__eqxf2", .linkage = common.linkage, .visibility = common.visibility });
    @export(__nexf2, .{ .name = "__nexf2", .linkage = common.linkage, .visibility = common.visibility });
    @export(__lexf2, .{ .name = "__lexf2", .linkage = common.linkage, .visibility = common.visibility });
    @export(__cmpxf2, .{ .name = "__cmpxf2", .linkage = common.linkage, .visibility = common.visibility });
    @export(__ltxf2, .{ .name = "__ltxf2", .linkage = common.linkage, .visibility = common.visibility });
}

/// "These functions calculate a <=> b. That is, if a is less than b, they return -1;
/// if a is greater than b, they return 1; and if a and b are equal they return 0.
/// If either argument is NaN they return 1..."
///
/// Note that this matches the definition of `__lexf2`, `__eqxf2`, `__nexf2`, `__cmpxf2`,
/// and `__ltxf2`.
fn __cmpxf2(a: f80, b: f80) callconv(.C) i32 {
    return @intFromEnum(comparef.cmp_f80(comparef.LE, a, b));
}

/// "These functions return a value less than or equal to zero if neither argument is NaN,
/// and a is less than or equal to b."
fn __lexf2(a: f80, b: f80) callconv(.C) i32 {
    return __cmpxf2(a, b);
}

/// "These functions return zero if neither argument is NaN, and a and b are equal."
/// Note that due to some kind of historical accident, __eqxf2 and __nexf2 are defined
/// to have the same return value.
fn __eqxf2(a: f80, b: f80) callconv(.C) i32 {
    return __cmpxf2(a, b);
}

/// "These functions return a nonzero value if either argument is NaN, or if a and b are unequal."
/// Note that due to some kind of historical accident, __eqxf2 and __nexf2 are defined
/// to have the same return value.
fn __nexf2(a: f80, b: f80) callconv(.C) i32 {
    return __cmpxf2(a, b);
}

/// "These functions return a value less than zero if neither argument is NaN, and a
/// is strictly less than b."
fn __ltxf2(a: f80, b: f80) callconv(.C) i32 {
    return __cmpxf2(a, b);
}
