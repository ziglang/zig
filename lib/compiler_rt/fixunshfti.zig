const builtin = @import("builtin");
const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(__fixunshfti_windows_x86_64, .{ .name = "__fixunshfti", .linkage = common.linkage });
    } else {
        @export(__fixunshfti, .{ .name = "__fixunshfti", .linkage = common.linkage });
    }
}

pub fn __fixunshfti(a: f16) callconv(.C) u128 {
    return floatToInt(u128, a);
}

const v2u64 = @import("std").meta.Vector(2, u64);

fn __fixunshfti_windows_x86_64(a: f16) callconv(.C) v2u64 {
    return @bitCast(v2u64, floatToInt(u128, a));
}
