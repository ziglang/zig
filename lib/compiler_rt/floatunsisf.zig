const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_ui2f, .{ .name = "__aeabi_ui2f", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(__floatunsisf, .{ .name = "__floatunsisf", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __floatunsisf(a: u32) callconv(.C) f32 {
    return intToFloat(f32, a);
}

fn __aeabi_ui2f(a: u32) callconv(.AAPCS) f32 {
    return intToFloat(f32, a);
}
