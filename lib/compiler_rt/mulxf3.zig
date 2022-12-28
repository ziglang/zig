const common = @import("./common.zig");
const mulf3 = @import("./mulf3.zig").mulf3;

pub const panic = common.panic;

comptime {
    @export(__mulxf3, .{ .name = "__mulxf3", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __mulxf3(a: f80, b: f80) callconv(.C) f80 {
    return mulf3(f80, a, b);
}
