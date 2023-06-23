const common = @import("./common.zig");
const floatFromInt = @import("./float_from_int.zig").floatFromInt;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_i2d, .{ .name = "__aeabi_i2d", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(__floatsidf, .{ .name = "__floatsidf", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __floatsidf(a: i32) callconv(.C) f64 {
    return floatFromInt(f64, a);
}

fn __aeabi_i2d(a: i32) callconv(.AAPCS) f64 {
    return floatFromInt(f64, a);
}
