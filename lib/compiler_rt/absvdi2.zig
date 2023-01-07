const common = @import("./common.zig");
const absv = @import("./absv.zig").absv;

pub const panic = common.panic;

comptime {
    @export(__absvdi2, .{ .name = "__absvdi2", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __absvdi2(a: i64) callconv(.C) i64 {
    return absv(i64, a);
}
