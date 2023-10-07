const common = @import("./common.zig");
const intFromFloat = @import("./int_from_float.zig").intFromFloat;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_d2iz, .{ .name = "__aeabi_d2iz", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(__fixdfsi, .{ .name = "__fixdfsi", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __fixdfsi(a: f64) callconv(.C) i32 {
    return intFromFloat(i32, a);
}

fn __aeabi_d2iz(a: f64) callconv(.AAPCS) i32 {
    return intFromFloat(i32, a);
}
