const common = @import("./common.zig");

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__subkf3, .{ .name = "__subkf3", .linkage = common.linkage });
    } else {
        @export(__subtf3, .{ .name = "__subtf3", .linkage = common.linkage });
    }
}

fn __subtf3(a: f128, b: f128) callconv(.C) f128 {
    const neg_b = @bitCast(f128, @bitCast(u128, b) ^ (@as(u128, 1) << 127));
    return a + neg_b;
}

fn __subkf3(a: f128, b: f128) callconv(.C) f128 {
    const neg_b = @bitCast(f128, @bitCast(u128, b) ^ (@as(u128, 1) << 127));
    return a + neg_b;
}
