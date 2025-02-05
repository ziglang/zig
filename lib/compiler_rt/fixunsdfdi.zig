const builtin = @import("builtin");
const common = @import("./common.zig");
const intFromFloat = @import("./int_from_float.zig").intFromFloat;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(&__aeabi_d2ulz, .{ .name = "__aeabi_d2ulz", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(&__fixunsdfdi, .{ .name = if (common.want_windows_arm_abi) "__dtou64" else "__fixunsdfdi", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __fixunsdfdi(a: f64) callconv(.C) u64 {
    return intFromFloat(u64, a);
}

fn __aeabi_d2ulz(a: f64) callconv(.AAPCS) u64 {
    return intFromFloat(u64, a);
}
