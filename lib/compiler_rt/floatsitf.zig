const common = @import("./common.zig");
const floatFromInt = @import("./float_from_int.zig").floatFromInt;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__floatsitf, .{ .name = "__floatsikf", .linkage = common.linkage, .visibility = common.visibility });
    } else if (common.want_sparc_abi) {
        @export(_Qp_itoq, .{ .name = "_Qp_itoq", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(__floatsitf, .{ .name = "__floatsitf", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __floatsitf(a: i32) callconv(.C) f128 {
    return floatFromInt(f128, a);
}

fn _Qp_itoq(c: *f128, a: i32) callconv(.C) void {
    c.* = floatFromInt(f128, a);
}
