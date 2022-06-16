const common = @import("./common.zig");
const addf3 = @import("./addf3.zig").addf3;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__addkf3, .{ .name = "__addkf3", .linkage = common.linkage });
    } else if (common.want_sparc_abi) {
        @export(_Qp_add, .{ .name = "_Qp_add", .linkage = common.linkage });
    } else {
        @export(__addtf3, .{ .name = "__addtf3", .linkage = common.linkage });
    }
}

pub fn __addtf3(a: f128, b: f128) callconv(.C) f128 {
    return addf3(f128, a, b);
}

fn __addkf3(a: f128, b: f128) callconv(.C) f128 {
    return addf3(f128, a, b);
}

fn _Qp_add(c: *f128, a: *f128, b: *f128) callconv(.C) void {
    c.* = addf3(f128, a.*, b.*);
}
