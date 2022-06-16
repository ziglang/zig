const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_i2d, .{ .name = "__aeabi_i2d", .linkage = common.linkage });
    } else {
        @export(__floatsidf, .{ .name = "__floatsidf", .linkage = common.linkage });
    }
}

pub fn __floatsidf(a: i32) callconv(.C) f64 {
    return intToFloat(f64, a);
}

fn __aeabi_i2d(a: i32) callconv(.AAPCS) f64 {
    return intToFloat(f64, a);
}
