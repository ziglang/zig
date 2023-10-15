const common = @import("./common.zig");
const addf3 = @import("./addf3.zig").addf3;

pub const panic = common.panic;

comptime {
    @export(__subhf3, .{ .name = "__subhf3", .linkage = common.linkage, .visibility = common.visibility });
}

fn __subhf3(a: f16, b: f16) callconv(.C) f16 {
    const neg_b = @as(f16, @bitCast(@as(u16, @bitCast(b)) ^ (@as(u16, 1) << 15)));
    return addf3(f16, a, neg_b);
}
