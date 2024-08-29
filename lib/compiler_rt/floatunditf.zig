const common = @import("./common.zig");
const floatFromInt = @import("./float_from_int.zig").floatFromInt;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(&__floatunditf, .{ .name = "__floatundikf", .linkage = common.linkage, .visibility = common.visibility });
    } else if (common.want_sparc_abi) {
        @export(&_Qp_uxtoq, .{ .name = "_Qp_uxtoq", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(&__floatunditf, .{ .name = "__floatunditf", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __floatunditf(a: u64) callconv(.C) f128 {
    return floatFromInt(f128, a);
}

fn _Qp_uxtoq(c: *f128, a: u64) callconv(.C) void {
    c.* = floatFromInt(f128, a);
}
