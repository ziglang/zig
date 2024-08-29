const common = @import("./common.zig");
const addf3 = @import("./addf3.zig").addf3;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(&__aeabi_dsub, .{ .name = "__aeabi_dsub", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(&__subdf3, .{ .name = "__subdf3", .linkage = common.linkage, .visibility = common.visibility });
    }
}

fn __subdf3(a: f64, b: f64) callconv(.C) f64 {
    return sub(a, b);
}

fn __aeabi_dsub(a: f64, b: f64) callconv(.AAPCS) f64 {
    return sub(a, b);
}

inline fn sub(a: f64, b: f64) f64 {
    const neg_b = @as(f64, @bitCast(@as(u64, @bitCast(b)) ^ (@as(u64, 1) << 63)));
    return addf3(f64, a, neg_b);
}
