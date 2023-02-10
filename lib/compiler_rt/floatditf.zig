const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__floatditf, .{ .name = "__floatdikf", .linkage = common.linkage, .visibility = common.visibility });
    } else if (common.want_sparc_abi) {
        @export(_Qp_xtoq, .{ .name = "_Qp_xtoq", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(__floatditf, .{ .name = "__floatditf", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __floatditf(a: i64) callconv(.C) f128 {
    return intToFloat(f128, a);
}

fn _Qp_xtoq(c: *f128, a: i64) callconv(.C) void {
    c.* = intToFloat(f128, a);
}
