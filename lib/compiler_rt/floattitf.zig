const builtin = @import("builtin");
const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(__floattitf_windows_x86_64, .{ .name = "__floattitf", .linkage = common.linkage });
    } else {
        @export(__floattitf, .{ .name = "__floattitf", .linkage = common.linkage });
    }
}

pub fn __floattitf(a: i128) callconv(.C) f128 {
    return intToFloat(f128, a);
}

fn __floattitf_windows_x86_64(a: @Vector(2, u64)) callconv(.C) f128 {
    return intToFloat(f128, @bitCast(i128, a));
}
