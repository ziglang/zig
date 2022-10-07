const common = @import("./common.zig");

pub const panic = common.panic;

comptime {
    @export(__subhf3, .{ .name = "__subhf3", .linkage = common.linkage });
}

fn __subhf3(a: f16, b: f16) callconv(.C) f16 {
    const neg_b = @bitCast(f16, @bitCast(u16, b) ^ (@as(u16, 1) << 15));
    return a + neg_b;
}
