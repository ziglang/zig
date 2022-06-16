const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_f2ulz, .{ .name = "__aeabi_f2ulz", .linkage = common.linkage });
    } else {
        @export(__fixunssfdi, .{ .name = "__fixunssfdi", .linkage = common.linkage });
    }
}

pub fn __fixunssfdi(a: f32) callconv(.C) u64 {
    return floatToInt(u64, a);
}

fn __aeabi_f2ulz(a: f32) callconv(.AAPCS) u64 {
    return floatToInt(u64, a);
}
