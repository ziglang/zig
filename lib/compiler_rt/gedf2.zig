///! The quoted behavior definitions are from
///! https://gcc.gnu.org/onlinedocs/gcc-12.1.0/gccint/Soft-float-library-routines.html#Soft-float-library-routines
const common = @import("./common.zig");
const comparef = @import("./comparef.zig");

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_dcmpge, .{ .name = "__aeabi_dcmpge", .linkage = common.linkage, .visibility = common.visibility });
        @export(__aeabi_dcmpgt, .{ .name = "__aeabi_dcmpgt", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(__gedf2, .{ .name = "__gedf2", .linkage = common.linkage, .visibility = common.visibility });
        @export(__gtdf2, .{ .name = "__gtdf2", .linkage = common.linkage, .visibility = common.visibility });
    }
}

/// "These functions return a value greater than or equal to zero if neither
/// argument is NaN, and a is greater than or equal to b."
pub fn __gedf2(a: f64, b: f64) callconv(.C) i32 {
    return @intFromEnum(comparef.cmpf2(f64, comparef.GE, a, b));
}

/// "These functions return a value greater than zero if neither argument is NaN,
/// and a is strictly greater than b."
pub fn __gtdf2(a: f64, b: f64) callconv(.C) i32 {
    return __gedf2(a, b);
}

fn __aeabi_dcmpge(a: f64, b: f64) callconv(.AAPCS) i32 {
    return @intFromBool(comparef.cmpf2(f64, comparef.GE, a, b) != .Less);
}

fn __aeabi_dcmpgt(a: f64, b: f64) callconv(.AAPCS) i32 {
    return @intFromBool(comparef.cmpf2(f64, comparef.GE, a, b) == .Greater);
}
