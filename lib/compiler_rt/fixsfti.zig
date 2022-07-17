const builtin = @import("builtin");
const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(__fixsfti_windows_x86_64, .{ .name = "__fixsfti", .linkage = common.linkage });
    } else {
        @export(__fixsfti, .{ .name = "__fixsfti", .linkage = common.linkage });
    }
}

pub fn __fixsfti(a: f32) callconv(.C) i128 {
    return floatToInt(i128, a);
}

const v2u64 = @Vector(2, u64);

fn __fixsfti_windows_x86_64(a: f32) callconv(.C) v2u64 {
    return @bitCast(v2u64, floatToInt(i128, a));
}
