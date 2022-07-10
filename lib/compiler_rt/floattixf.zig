const builtin = @import("builtin");
const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(__floattixf_windows_x86_64, .{ .name = "__floattixf", .linkage = common.linkage });
    } else {
        @export(__floattixf, .{ .name = "__floattixf", .linkage = common.linkage });
    }
}

pub fn __floattixf(a: i128) callconv(.C) f80 {
    return intToFloat(f80, a);
}

fn __floattixf_windows_x86_64(a: @Vector(2, u64)) callconv(.C) f80 {
    return intToFloat(f80, @bitCast(i128, a));
}
