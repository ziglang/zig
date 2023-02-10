const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_l2f, .{ .name = "__aeabi_l2f", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(__floatdisf, .{ .name = "__floatdisf", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __floatdisf(a: i64) callconv(.C) f32 {
    return intToFloat(f32, a);
}

fn __aeabi_l2f(a: i64) callconv(.AAPCS) f32 {
    return intToFloat(f32, a);
}
