const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__floatdikf, .{ .name = "__floatdikf", .linkage = common.linkage });
    } else {
        @export(__floatditf, .{ .name = "__floatditf", .linkage = common.linkage });
    }
}

fn __floatditf(a: i64) callconv(.C) f128 {
    return intToFloat(f128, a);
}

fn __floatdikf(a: i64) callconv(.C) f128 {
    return intToFloat(f128, a);
}
