///! The quoted behavior definitions are from
///! https://gcc.gnu.org/onlinedocs/gcc-12.1.0/gccint/Soft-float-library-routines.html#Soft-float-library-routines
const common = @import("./common.zig");
const comparef = @import("./comparef.zig");

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(&__aeabi_dcmpeq, .{ .name = "__aeabi_dcmpeq", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__aeabi_dcmplt, .{ .name = "__aeabi_dcmplt", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__aeabi_dcmple, .{ .name = "__aeabi_dcmple", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(&__eqdf2, .{ .name = "__eqdf2", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__nedf2, .{ .name = "__nedf2", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__ledf2, .{ .name = "__ledf2", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__cmpdf2, .{ .name = "__cmpdf2", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__ltdf2, .{ .name = "__ltdf2", .linkage = common.linkage, .visibility = common.visibility });
    }
}

/// "These functions calculate a <=> b. That is, if a is less than b, they return -1;
/// if a is greater than b, they return 1; and if a and b are equal they return 0.
/// If either argument is NaN they return 1..."
///
/// Note that this matches the definition of `__ledf2`, `__eqdf2`, `__nedf2`, `__cmpdf2`,
/// and `__ltdf2`.
fn __cmpdf2(a: f64, b: f64) callconv(.C) i32 {
    return @intFromEnum(comparef.cmpf2(f64, comparef.LE, a, b));
}

/// "These functions return a value less than or equal to zero if neither argument is NaN,
/// and a is less than or equal to b."
pub fn __ledf2(a: f64, b: f64) callconv(.C) i32 {
    return __cmpdf2(a, b);
}

/// "These functions return zero if neither argument is NaN, and a and b are equal."
/// Note that due to some kind of historical accident, __eqdf2 and __nedf2 are defined
/// to have the same return value.
pub fn __eqdf2(a: f64, b: f64) callconv(.C) i32 {
    return __cmpdf2(a, b);
}

/// "These functions return a nonzero value if either argument is NaN, or if a and b are unequal."
/// Note that due to some kind of historical accident, __eqdf2 and __nedf2 are defined
/// to have the same return value.
pub fn __nedf2(a: f64, b: f64) callconv(.C) i32 {
    return __cmpdf2(a, b);
}

/// "These functions return a value less than zero if neither argument is NaN, and a
/// is strictly less than b."
pub fn __ltdf2(a: f64, b: f64) callconv(.C) i32 {
    return __cmpdf2(a, b);
}

fn __aeabi_dcmpeq(a: f64, b: f64) callconv(.AAPCS) i32 {
    return @intFromBool(comparef.cmpf2(f64, comparef.LE, a, b) == .Equal);
}

fn __aeabi_dcmplt(a: f64, b: f64) callconv(.AAPCS) i32 {
    return @intFromBool(comparef.cmpf2(f64, comparef.LE, a, b) == .Less);
}

fn __aeabi_dcmple(a: f64, b: f64) callconv(.AAPCS) i32 {
    return @intFromBool(comparef.cmpf2(f64, comparef.LE, a, b) != .Greater);
}
