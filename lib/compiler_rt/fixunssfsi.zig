const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_f2uiz, .{ .name = "__aeabi_f2uiz", .linkage = common.linkage });
    } else {
        @export(__fixunssfsi, .{ .name = "__fixunssfsi", .linkage = common.linkage });
    }
}

pub fn __fixunssfsi(a: f32) callconv(.C) u32 {
    return floatToInt(u32, a);
}

fn __aeabi_f2uiz(a: f32) callconv(.AAPCS) u32 {
    return floatToInt(u32, a);
}
