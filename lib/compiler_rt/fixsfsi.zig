const common = @import("./common.zig");
const intFromFloat = @import("./int_from_float.zig").intFromFloat;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(&__aeabi_f2iz, .{ .name = "__aeabi_f2iz", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(&__fixsfsi, .{ .name = "__fixsfsi", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __fixsfsi(a: f32) callconv(.C) i32 {
    return intFromFloat(i32, a);
}

fn __aeabi_f2iz(a: f32) callconv(.AAPCS) i32 {
    return intFromFloat(i32, a);
}
