const builtin = @import("builtin");
const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(__fixunsdfti_windows_x86_64, .{ .name = "__fixunsdfti", .linkage = common.linkage });
    } else {
        @export(__fixunsdfti, .{ .name = "__fixunsdfti", .linkage = common.linkage });
    }
}

pub fn __fixunsdfti(a: f64) callconv(.C) u128 {
    return floatToInt(u128, a);
}

const v2u64 = @Vector(2, u64);

fn __fixunsdfti_windows_x86_64(a: f64) callconv(.C) v2u64 {
    return @bitCast(v2u64, floatToInt(u128, a));
}
