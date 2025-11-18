const builtin = @import("builtin");
const common = @import("./common.zig");
const intFromFloat = @import("./int_from_float.zig").intFromFloat;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(&__aeabi_f2ulz, .{ .name = "__aeabi_f2ulz", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        if (common.want_windows_arm_abi) {
            @export(&__fixunssfdi, .{ .name = "__stou64", .linkage = common.linkage, .visibility = common.visibility });
        }
        @export(&__fixunssfdi, .{ .name = "__fixunssfdi", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __fixunssfdi(a: f32) callconv(.c) u64 {
    return intFromFloat(u64, a);
}

fn __aeabi_f2ulz(a: f32) callconv(.{ .arm_aapcs = .{} }) u64 {
    return intFromFloat(u64, a);
}
