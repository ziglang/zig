const builtin = @import("builtin");
const common = @import("./common.zig");
const intFromFloat = @import("./int_from_float.zig").intFromFloat;

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(__fixsfti_windows_x86_64, .{ .name = "__fixsfti", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(__fixsfti, .{ .name = "__fixsfti", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __fixsfti(a: f32) callconv(.C) i128 {
    return intFromFloat(i128, a);
}

const v2u64 = @Vector(2, u64);

fn __fixsfti_windows_x86_64(a: f32) callconv(.C) v2u64 {
    return @bitCast(v2u64, intFromFloat(i128, a));
}
