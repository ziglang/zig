const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_f2iz, .{ .name = "__aeabi_f2iz", .linkage = common.linkage });
    } else {
        @export(__fixsfsi, .{ .name = "__fixsfsi", .linkage = common.linkage });
    }
}

pub fn __fixsfsi(a: f32) callconv(.C) i32 {
    return floatToInt(i32, a);
}

fn __aeabi_f2iz(a: f32) callconv(.AAPCS) i32 {
    return floatToInt(i32, a);
}
