const builtin = @import("builtin");
const common = @import("./common.zig");
const intFromFloat = @import("./int_from_float.zig").intFromFloat;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(&__aeabi_d2ulz, .{ .name = "__aeabi_d2ulz", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(&__fixunsdfdi, .{ .name = "__fixunsdfdi", .linkage = common.linkage, .visibility = common.visibility });

        if (common.want_mingw_arm_abi) {
            @export(&__fixunsdfdi, .{ .name = "__dtou64", .linkage = common.linkage, .visibility = common.visibility });
        }
    }
}

pub fn __fixunsdfdi(a: f64) callconv(.C) u64 {
    return intFromFloat(u64, a);
}

fn __aeabi_d2ulz(a: f64) callconv(.AAPCS) u64 {
    return intFromFloat(u64, a);
}
