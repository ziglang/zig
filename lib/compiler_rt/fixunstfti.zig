const builtin = @import("builtin");
const common = @import("./common.zig");
const intFromFloat = @import("./int_from_float.zig").intFromFloat;

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(__fixunstfti_windows_x86_64, .{ .name = "__fixunstfti", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        if (common.want_ppc_abi)
            @export(__fixunstfti, .{ .name = "__fixunskfti", .linkage = common.linkage, .visibility = common.visibility });
        @export(__fixunstfti, .{ .name = "__fixunstfti", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __fixunstfti(a: f128) callconv(.C) u128 {
    return intFromFloat(u128, a);
}

const v2u64 = @Vector(2, u64);

fn __fixunstfti_windows_x86_64(a: f128) callconv(.C) v2u64 {
    return @as(v2u64, @bitCast(intFromFloat(u128, a)));
}
