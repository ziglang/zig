///! The quoted behavior definitions are from
///! https://gcc.gnu.org/onlinedocs/gcc-12.1.0/gccint/Soft-float-library-routines.html#Soft-float-library-routines
const common = @import("./common.zig");
const comparef = @import("./comparef.zig");

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(&__aeabi_fcmpge, .{ .name = "__aeabi_fcmpge", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__aeabi_fcmpgt, .{ .name = "__aeabi_fcmpgt", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(&__gesf2, .{ .name = "__gesf2", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__gtsf2, .{ .name = "__gtsf2", .linkage = common.linkage, .visibility = common.visibility });
    }
}

/// "These functions return a value greater than or equal to zero if neither
/// argument is NaN, and a is greater than or equal to b."
pub fn __gesf2(a: f32, b: f32) callconv(.C) i32 {
    return @intFromEnum(comparef.cmpf2(f32, comparef.GE, a, b));
}

/// "These functions return a value greater than zero if neither argument is NaN,
/// and a is strictly greater than b."
pub fn __gtsf2(a: f32, b: f32) callconv(.C) i32 {
    return __gesf2(a, b);
}

fn __aeabi_fcmpge(a: f32, b: f32) callconv(.AAPCS) i32 {
    return @intFromBool(comparef.cmpf2(f32, comparef.GE, a, b) != .Less);
}

fn __aeabi_fcmpgt(a: f32, b: f32) callconv(.AAPCS) i32 {
    return @intFromBool(comparef.cmpf2(f32, comparef.LE, a, b) == .Greater);
}
