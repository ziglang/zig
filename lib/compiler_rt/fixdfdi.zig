const builtin = @import("builtin");
const common = @import("./common.zig");
const intFromFloat = @import("./int_from_float.zig").intFromFloat;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(&__aeabi_d2lz, .{ .name = "__aeabi_d2lz", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        if (common.want_windows_arm_abi) {
            @export(&__fixdfdi, .{ .name = "__dtoi64", .linkage = common.linkage, .visibility = common.visibility });
        }
        @export(&__fixdfdi, .{ .name = "__fixdfdi", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __fixdfdi(a: f64) callconv(.c) i64 {
    return intFromFloat(i64, a);
}

fn __aeabi_d2lz(a: f64) callconv(.{ .arm_aapcs = .{} }) i64 {
    return intFromFloat(i64, a);
}
