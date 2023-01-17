const common = @import("./common.zig");
const absv = @import("./absv.zig").absv;

pub const panic = common.panic;

comptime {
    @export(__absvti2, .{ .name = "__absvti2", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __absvti2(a: i128) callconv(.C) i128 {
    return absv(i128, a);
}
