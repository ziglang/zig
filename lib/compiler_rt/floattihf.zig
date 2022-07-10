const builtin = @import("builtin");
const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(__floattihf_windows_x86_64, .{ .name = "__floattihf", .linkage = common.linkage });
    } else {
        @export(__floattihf, .{ .name = "__floattihf", .linkage = common.linkage });
    }
}

pub fn __floattihf(a: i128) callconv(.C) f16 {
    return intToFloat(f16, a);
}

fn __floattihf_windows_x86_64(a: @Vector(2, u64)) callconv(.C) f16 {
    return intToFloat(f16, @bitCast(i128, a));
}
