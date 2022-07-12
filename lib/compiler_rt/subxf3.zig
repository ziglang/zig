const std = @import("std");
const common = @import("./common.zig");

pub const panic = common.panic;

comptime {
    if (common.should_emit_f80_or_f128) {
        @export(__subxf3, .{ .name = "__subxf3", .linkage = common.linkage });
    }
}

fn __subxf3(a: f80, b: f80) callconv(.C) f80 {
    var b_rep = std.math.break_f80(b);
    b_rep.exp ^= 0x8000;
    const neg_b = std.math.make_f80(b_rep);
    return a + neg_b;
}
