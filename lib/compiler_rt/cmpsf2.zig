///! The quoted behavior definitions are from
///! https://gcc.gnu.org/onlinedocs/gcc-12.1.0/gccint/Soft-float-library-routines.html#Soft-float-library-routines
const common = @import("./common.zig");
const comparef = @import("./comparef.zig");

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_fcmpeq, .{ .name = "__aeabi_fcmpeq", .linkage = common.linkage, .visibility = common.visibility });
        @export(__aeabi_fcmplt, .{ .name = "__aeabi_fcmplt", .linkage = common.linkage, .visibility = common.visibility });
        @export(__aeabi_fcmple, .{ .name = "__aeabi_fcmple", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(__eqsf2, .{ .name = "__eqsf2", .linkage = common.linkage, .visibility = common.visibility });
        @export(__nesf2, .{ .name = "__nesf2", .linkage = common.linkage, .visibility = common.visibility });
        @export(__lesf2, .{ .name = "__lesf2", .linkage = common.linkage, .visibility = common.visibility });
        @export(__cmpsf2, .{ .name = "__cmpsf2", .linkage = common.linkage, .visibility = common.visibility });
        @export(__ltsf2, .{ .name = "__ltsf2", .linkage = common.linkage, .visibility = common.visibility });
    }
}

/// "These functions calculate a <=> b. That is, if a is less than b, they return -1;
/// if a is greater than b, they return 1; and if a and b are equal they return 0.
/// If either argument is NaN they return 1..."
///
/// Note that this matches the definition of `__lesf2`, `__eqsf2`, `__nesf2`, `__cmpsf2`,
/// and `__ltsf2`.
fn __cmpsf2(a: f32, b: f32) callconv(.C) i32 {
    return @intFromEnum(comparef.cmpf2(f32, comparef.LE, a, b));
}

/// "These functions return a value less than or equal to zero if neither argument is NaN,
/// and a is less than or equal to b."
pub fn __lesf2(a: f32, b: f32) callconv(.C) i32 {
    return __cmpsf2(a, b);
}

/// "These functions return zero if neither argument is NaN, and a and b are equal."
/// Note that due to some kind of historical accident, __eqsf2 and __nesf2 are defined
/// to have the same return value.
pub fn __eqsf2(a: f32, b: f32) callconv(.C) i32 {
    return __cmpsf2(a, b);
}

/// "These functions return a nonzero value if either argument is NaN, or if a and b are unequal."
/// Note that due to some kind of historical accident, __eqsf2 and __nesf2 are defined
/// to have the same return value.
pub fn __nesf2(a: f32, b: f32) callconv(.C) i32 {
    return __cmpsf2(a, b);
}

/// "These functions return a value less than zero if neither argument is NaN, and a
/// is strictly less than b."
pub fn __ltsf2(a: f32, b: f32) callconv(.C) i32 {
    return __cmpsf2(a, b);
}

fn __aeabi_fcmpeq(a: f32, b: f32) callconv(.AAPCS) i32 {
    return @intFromBool(comparef.cmpf2(f32, comparef.LE, a, b) == .Equal);
}

fn __aeabi_fcmplt(a: f32, b: f32) callconv(.AAPCS) i32 {
    return @intFromBool(comparef.cmpf2(f32, comparef.LE, a, b) == .Less);
}

fn __aeabi_fcmple(a: f32, b: f32) callconv(.AAPCS) i32 {
    return @intFromBool(comparef.cmpf2(f32, comparef.LE, a, b) != .Greater);
}
