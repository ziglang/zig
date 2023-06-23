///! The quoted behavior definitions are from
///! https://gcc.gnu.org/onlinedocs/gcc-12.1.0/gccint/Soft-float-library-routines.html#Soft-float-library-routines
const common = @import("./common.zig");
const comparef = @import("./comparef.zig");

pub const panic = common.panic;

comptime {
    @export(__gehf2, .{ .name = "__gehf2", .linkage = common.linkage, .visibility = common.visibility });
    @export(__gthf2, .{ .name = "__gthf2", .linkage = common.linkage, .visibility = common.visibility });
}

/// "These functions return a value greater than or equal to zero if neither
/// argument is NaN, and a is greater than or equal to b."
pub fn __gehf2(a: f16, b: f16) callconv(.C) i32 {
    return @intFromEnum(comparef.cmpf2(f16, comparef.GE, a, b));
}

/// "These functions return a value greater than zero if neither argument is NaN,
/// and a is strictly greater than b."
pub fn __gthf2(a: f16, b: f16) callconv(.C) i32 {
    return __gehf2(a, b);
}
