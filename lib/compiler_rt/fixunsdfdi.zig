const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_d2ulz, .{ .name = "__aeabi_d2ulz", .linkage = common.linkage });
    } else {
        @export(__fixunsdfdi, .{ .name = "__fixunsdfdi", .linkage = common.linkage });
    }
}

pub fn __fixunsdfdi(a: f64) callconv(.C) u64 {
    return floatToInt(u64, a);
}

fn __aeabi_d2ulz(a: f64) callconv(.AAPCS) u64 {
    return floatToInt(u64, a);
}
