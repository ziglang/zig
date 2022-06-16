const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_ul2f, .{ .name = "__aeabi_ul2f", .linkage = common.linkage });
    } else {
        @export(__floatundisf, .{ .name = "__floatundisf", .linkage = common.linkage });
    }
}

pub fn __floatundisf(a: u64) callconv(.C) f32 {
    return intToFloat(f32, a);
}

fn __aeabi_ul2f(a: u64) callconv(.AAPCS) f32 {
    return intToFloat(f32, a);
}
