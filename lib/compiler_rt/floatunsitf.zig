const common = @import("./common.zig");
const floatFromInt = @import("./float_from_int.zig").floatFromInt;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__floatunsitf, .{ .name = "__floatunsikf", .linkage = common.linkage, .visibility = common.visibility });
    } else if (common.want_sparc_abi) {
        @export(_Qp_uitoq, .{ .name = "_Qp_uitoq", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(__floatunsitf, .{ .name = "__floatunsitf", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __floatunsitf(a: u32) callconv(.C) f128 {
    return floatFromInt(f128, a);
}

fn _Qp_uitoq(c: *f128, a: u32) callconv(.C) void {
    c.* = floatFromInt(f128, a);
}
