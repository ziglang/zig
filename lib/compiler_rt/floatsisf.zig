const common = @import("./common.zig");
const floatFromInt = @import("./float_from_int.zig").floatFromInt;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_i2f, .{ .name = "__aeabi_i2f", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(__floatsisf, .{ .name = "__floatsisf", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __floatsisf(a: i32) callconv(.C) f32 {
    return floatFromInt(f32, a);
}

fn __aeabi_i2f(a: i32) callconv(.AAPCS) f32 {
    return floatFromInt(f32, a);
}
