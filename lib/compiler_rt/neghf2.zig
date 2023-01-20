const common = @import("./common.zig");

pub const panic = common.panic;

comptime {
    @export(__neghf2, .{ .name = "__neghf2", .linkage = common.linkage, .visibility = common.visibility });
}

fn __neghf2(a: f16) callconv(.C) f16 {
    return common.fneg(a);
}
