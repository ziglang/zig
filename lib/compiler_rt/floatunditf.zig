const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__floatundikf, .{ .name = "__floatundikf", .linkage = common.linkage });
    } else if (common.want_sparc_abi) {
        @export(_Qp_uxtoq, .{ .name = "_Qp_uxtoq", .linkage = common.linkage });
    } else {
        @export(__floatunditf, .{ .name = "__floatunditf", .linkage = common.linkage });
    }
}

pub fn __floatunditf(a: u64) callconv(.C) f128 {
    return intToFloat(f128, a);
}

fn __floatundikf(a: u64) callconv(.C) f128 {
    return intToFloat(f128, a);
}

fn _Qp_uxtoq(c: *f128, a: u64) callconv(.C) void {
    c.* = intToFloat(f128, a);
}
