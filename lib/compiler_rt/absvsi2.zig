const common = @import("./common.zig");
const absv = @import("./absv.zig").absv;

pub const panic = common.panic;

comptime {
    @export(&__absvsi2, .{ .name = "__absvsi2", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __absvsi2(a: i32) callconv(.C) i32 {
    return absv(i32, a);
}
