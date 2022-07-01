const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_i2f, .{ .name = "__aeabi_i2f", .linkage = common.linkage });
    } else {
        @export(__floatsisf, .{ .name = "__floatsisf", .linkage = common.linkage });
    }
}

pub fn __floatsisf(a: i32) callconv(.C) f32 {
    return intToFloat(f32, a);
}

fn __aeabi_i2f(a: i32) callconv(.AAPCS) f32 {
    return intToFloat(f32, a);
}
