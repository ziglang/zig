const builtin = @import("builtin");
const common = @import("./common.zig");
const intFromFloat = @import("./int_from_float.zig").intFromFloat;

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(&__fixunsdfti_windows_x86_64, .{ .name = "__fixunsdfti", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(&__fixunsdfti, .{ .name = "__fixunsdfti", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __fixunsdfti(a: f64) callconv(.C) u128 {
    return intFromFloat(u128, a);
}

const v2u64 = @Vector(2, u64);

fn __fixunsdfti_windows_x86_64(a: f64) callconv(.C) v2u64 {
    return @bitCast(intFromFloat(u128, a));
}
