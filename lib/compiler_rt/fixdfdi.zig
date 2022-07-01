const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_d2lz, .{ .name = "__aeabi_d2lz", .linkage = common.linkage });
    } else {
        @export(__fixdfdi, .{ .name = "__fixdfdi", .linkage = common.linkage });
    }
}

pub fn __fixdfdi(a: f64) callconv(.C) i64 {
    return floatToInt(i64, a);
}

fn __aeabi_d2lz(a: f64) callconv(.AAPCS) i64 {
    return floatToInt(i64, a);
}
