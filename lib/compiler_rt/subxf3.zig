const std = @import("std");
const common = @import("./common.zig");

pub const panic = common.panic;

comptime {
    @export(&__subxf3, .{ .name = "__subxf3", .linkage = common.linkage, .visibility = common.visibility });
}

fn __subxf3(a: f80, b: f80) callconv(.C) f80 {
    var b_rep = std.math.F80.fromFloat(b);
    b_rep.exp ^= 0x8000;
    const neg_b = b_rep.toFloat();
    return a + neg_b;
}
