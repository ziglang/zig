const builtin = @import("builtin");
const common = @import("./common.zig");
const intFromFloat = @import("./int_from_float.zig").intFromFloat;

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(&__fixdfti_windows_x86_64, .{ .name = "__fixdfti", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(&__fixdfti, .{ .name = "__fixdfti", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __fixdfti(a: f64) callconv(.C) i128 {
    return intFromFloat(i128, a);
}

const v2u64 = @Vector(2, u64);

fn __fixdfti_windows_x86_64(a: f64) callconv(.C) v2u64 {
    return @bitCast(intFromFloat(i128, a));
}
