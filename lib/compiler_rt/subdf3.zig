const common = @import("./common.zig");

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_dsub, .{ .name = "__aeabi_dsub", .linkage = common.linkage });
    } else {
        @export(__subdf3, .{ .name = "__subdf3", .linkage = common.linkage });
    }
}

fn __subdf3(a: f64, b: f64) callconv(.C) f64 {
    const neg_b = @bitCast(f64, @bitCast(u64, b) ^ (@as(u64, 1) << 63));
    return a + neg_b;
}

fn __aeabi_dsub(a: f64, b: f64) callconv(.AAPCS) f64 {
    const neg_b = @bitCast(f64, @bitCast(u64, b) ^ (@as(u64, 1) << 63));
    return a + neg_b;
}
