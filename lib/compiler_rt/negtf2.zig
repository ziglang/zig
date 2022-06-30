const common = @import("./common.zig");

pub const panic = common.panic;

comptime {
    @export(__negtf2, .{ .name = "__negtf2", .linkage = common.linkage });
}

fn __negtf2(a: f128) callconv(.C) f128 {
    return common.fneg(a);
}
