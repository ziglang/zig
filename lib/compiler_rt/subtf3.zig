const common = @import("./common.zig");
const addf3 = @import("./addf3.zig").addf3;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__subtf3, .{ .name = "__subkf3", .linkage = common.linkage, .visibility = common.visibility });
    } else if (common.want_sparc_abi) {
        @export(_Qp_sub, .{ .name = "_Qp_sub", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(__subtf3, .{ .name = "__subtf3", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __subtf3(a: f128, b: f128) callconv(.C) f128 {
    return sub(a, b);
}

fn _Qp_sub(c: *f128, a: *const f128, b: *const f128) callconv(.C) void {
    c.* = sub(a.*, b.*);
}

inline fn sub(a: f128, b: f128) f128 {
    const neg_b = @as(f128, @bitCast(@as(u128, @bitCast(b)) ^ (@as(u128, 1) << 127)));
    return addf3(f128, a, neg_b);
}
