const builtin = @import("builtin");
const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(__floatuntihf_windows_x86_64, .{ .name = "__floatuntihf", .linkage = common.linkage });
    } else {
        @export(__floatuntihf, .{ .name = "__floatuntihf", .linkage = common.linkage });
    }
}

pub fn __floatuntihf(a: u128) callconv(.C) f16 {
    return intToFloat(f16, a);
}

fn __floatuntihf_windows_x86_64(a: @Vector(2, u64)) callconv(.C) f16 {
    return intToFloat(f16, @bitCast(u128, a));
}
