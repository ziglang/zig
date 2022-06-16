const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__floatunsikf, .{ .name = "__floatunsikf", .linkage = common.linkage });
    } else if (common.want_sparc_abi) {
        @export(_Qp_uitoq, .{ .name = "_Qp_uitoq", .linkage = common.linkage });
    } else {
        @export(__floatunsitf, .{ .name = "__floatunsitf", .linkage = common.linkage });
    }
}

pub fn __floatunsitf(a: u32) callconv(.C) f128 {
    return intToFloat(f128, a);
}

fn __floatunsikf(a: u32) callconv(.C) f128 {
    return intToFloat(f128, a);
}

fn _Qp_uitoq(c: *f128, a: u32) callconv(.C) void {
    c.* = intToFloat(f128, a);
}
