const common = @import("./common.zig");
const floatFromInt = @import("./float_from_int.zig").floatFromInt;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(&__aeabi_ui2d, .{ .name = "__aeabi_ui2d", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(&__floatunsidf, .{ .name = "__floatunsidf", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __floatunsidf(a: u32) callconv(.C) f64 {
    return floatFromInt(f64, a);
}

fn __aeabi_ui2d(a: u32) callconv(.AAPCS) f64 {
    return floatFromInt(f64, a);
}
