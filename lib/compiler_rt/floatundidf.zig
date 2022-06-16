const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_ul2d, .{ .name = "__aeabi_ul2d", .linkage = common.linkage });
    } else {
        @export(__floatundidf, .{ .name = "__floatundidf", .linkage = common.linkage });
    }
}

pub fn __floatundidf(a: u64) callconv(.C) f64 {
    return intToFloat(f64, a);
}

fn __aeabi_ul2d(a: u64) callconv(.AAPCS) f64 {
    return intToFloat(f64, a);
}
