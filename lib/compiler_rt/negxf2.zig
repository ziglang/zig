const common = @import("./common.zig");

pub const panic = common.panic;

comptime {
    @export(&__negxf2, .{ .name = "__negxf2", .linkage = common.linkage, .visibility = common.visibility });
}

fn __negxf2(a: f80) callconv(.C) f80 {
    return common.fneg(a);
}
