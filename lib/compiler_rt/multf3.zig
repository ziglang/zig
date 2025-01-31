const common = @import("./common.zig");
const mulf3 = @import("./mulf3.zig").mulf3;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(&__multf3, .{ .name = "__mulkf3", .linkage = common.linkage, .visibility = common.visibility });
    } else if (common.want_sparc_abi) {
        @export(&_Qp_mul, .{ .name = "_Qp_mul", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(&__multf3, .{ .name = "__multf3", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __multf3(a: f128, b: f128) callconv(.C) f128 {
    return mulf3(f128, a, b);
}

fn _Qp_mul(c: *f128, a: *const f128, b: *const f128) callconv(.C) void {
    c.* = mulf3(f128, a.*, b.*);
}
