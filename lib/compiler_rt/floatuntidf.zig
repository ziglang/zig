const builtin = @import("builtin");
const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(__floatuntidf_windows_x86_64, .{ .name = "__floatuntidf", .linkage = common.linkage });
    } else {
        @export(__floatuntidf, .{ .name = "__floatuntidf", .linkage = common.linkage });
    }
}

pub fn __floatuntidf(a: u128) callconv(.C) f64 {
    return intToFloat(f64, a);
}

fn __floatuntidf_windows_x86_64(a: @Vector(2, u64)) callconv(.C) f64 {
    return intToFloat(f64, @bitCast(u128, a));
}
