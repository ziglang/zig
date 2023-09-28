const builtin = @import("builtin");
const common = @import("./common.zig");
const intFromFloat = @import("./int_from_float.zig").intFromFloat;

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(__fixunshfti_windows_x86_64, .{ .name = "__fixunshfti", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(__fixunshfti, .{ .name = "__fixunshfti", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __fixunshfti(a: f16) callconv(.C) u128 {
    return intFromFloat(u128, a);
}

const v2u64 = @Vector(2, u64);

fn __fixunshfti_windows_x86_64(a: f16) callconv(.C) v2u64 {
    return @bitCast(intFromFloat(u128, a));
}
