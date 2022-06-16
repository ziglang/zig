const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_l2d, .{ .name = "__aeabi_l2d", .linkage = common.linkage });
    } else {
        @export(__floatdidf, .{ .name = "__floatdidf", .linkage = common.linkage });
    }
}

pub fn __floatdidf(a: i64) callconv(.C) f64 {
    return intToFloat(f64, a);
}

fn __aeabi_l2d(a: i64) callconv(.AAPCS) f64 {
    return intToFloat(f64, a);
}
