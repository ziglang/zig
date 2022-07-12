const common = @import("./common.zig");

pub const panic = common.panic;

comptime {
    if (common.should_emit_f80_or_f128) {
        @export(__negxf2, .{ .name = "__negxf2", .linkage = common.linkage });
    }
}

fn __negxf2(a: f80) callconv(.C) f80 {
    return common.fneg(a);
}
