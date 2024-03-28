const common = @import("./common.zig");
const floatFromInt = @import("./float_from_int.zig").floatFromInt;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(&__aeabi_l2f, .{ .name = "__aeabi_l2f", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(&__floatdisf, .{ .name = "__floatdisf", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __floatdisf(a: i64) callconv(.C) f32 {
    return floatFromInt(f32, a);
}

fn __aeabi_l2f(a: i64) callconv(.AAPCS) f32 {
    return floatFromInt(f32, a);
}
