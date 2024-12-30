const common = @import("./common.zig");
const comparef = @import("./comparef.zig");

pub const panic = common.panic;

comptime {
    @export(&__unordhf2, .{ .name = "__unordhf2", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __unordhf2(a: f16, b: f16) callconv(.C) i32 {
    return comparef.unordcmp(f16, a, b);
}
