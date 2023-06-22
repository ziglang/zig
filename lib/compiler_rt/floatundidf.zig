const common = @import("./common.zig");
const floatFromInt = @import("./float_from_int.zig").floatFromInt;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_ul2d, .{ .name = "__aeabi_ul2d", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(__floatundidf, .{ .name = "__floatundidf", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __floatundidf(a: u64) callconv(.C) f64 {
    return floatFromInt(f64, a);
}

fn __aeabi_ul2d(a: u64) callconv(.AAPCS) f64 {
    return floatFromInt(f64, a);
}
