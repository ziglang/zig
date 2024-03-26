const common = @import("./common.zig");
const intFromFloat = @import("./int_from_float.zig").intFromFloat;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(&__aeabi_f2lz, .{ .name = "__aeabi_f2lz", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(&__fixsfdi, .{ .name = "__fixsfdi", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __fixsfdi(a: f32) callconv(.C) i64 {
    return intFromFloat(i64, a);
}

fn __aeabi_f2lz(a: f32) callconv(.AAPCS) i64 {
    return intFromFloat(i64, a);
}
