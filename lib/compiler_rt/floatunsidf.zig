const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_ui2d, .{ .name = "__aeabi_ui2d", .linkage = common.linkage });
    } else {
        @export(__floatunsidf, .{ .name = "__floatunsidf", .linkage = common.linkage });
    }
}

pub fn __floatunsidf(a: u32) callconv(.C) f64 {
    return intToFloat(f64, a);
}

fn __aeabi_ui2d(a: u32) callconv(.AAPCS) f64 {
    return intToFloat(f64, a);
}
