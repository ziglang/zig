const common = @import("./common.zig");
const comparef = @import("./comparef.zig");

pub const panic = common.panic;

comptime {
    @export(&__unordxf2, .{ .name = "__unordxf2", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __unordxf2(a: f80, b: f80) callconv(.C) i32 {
    return comparef.unordcmp(f80, a, b);
}
