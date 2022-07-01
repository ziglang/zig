const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_f2lz, .{ .name = "__aeabi_f2lz", .linkage = common.linkage });
    } else {
        @export(__fixsfdi, .{ .name = "__fixsfdi", .linkage = common.linkage });
    }
}

pub fn __fixsfdi(a: f32) callconv(.C) i64 {
    return floatToInt(i64, a);
}

fn __aeabi_f2lz(a: f32) callconv(.AAPCS) i64 {
    return floatToInt(i64, a);
}
