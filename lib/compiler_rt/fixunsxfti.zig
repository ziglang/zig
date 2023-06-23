const builtin = @import("builtin");
const common = @import("./common.zig");
const intFromFloat = @import("./int_from_float.zig").intFromFloat;

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(__fixunsxfti_windows_x86_64, .{ .name = "__fixunsxfti", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(__fixunsxfti, .{ .name = "__fixunsxfti", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __fixunsxfti(a: f80) callconv(.C) u128 {
    return intFromFloat(u128, a);
}

const v2u64 = @Vector(2, u64);

fn __fixunsxfti_windows_x86_64(a: f80) callconv(.C) v2u64 {
    return @bitCast(v2u64, intFromFloat(u128, a));
}
