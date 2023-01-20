const common = @import("./common.zig");
const truncf = @import("./truncf.zig").truncf;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__trunctfdf2, .{ .name = "__trunckfdf2", .linkage = common.linkage, .visibility = common.visibility });
    } else if (common.want_sparc_abi) {
        @export(_Qp_qtod, .{ .name = "_Qp_qtod", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(__trunctfdf2, .{ .name = "__trunctfdf2", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __trunctfdf2(a: f128) callconv(.C) f64 {
    return truncf(f64, f128, a);
}

fn _Qp_qtod(a: *const f128) callconv(.C) f64 {
    return truncf(f64, f128, a.*);
}
