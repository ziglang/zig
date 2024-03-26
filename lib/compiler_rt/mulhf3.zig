const common = @import("./common.zig");
const mulf3 = @import("./mulf3.zig").mulf3;

pub const panic = common.panic;

comptime {
    @export(&__mulhf3, .{ .name = "__mulhf3", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __mulhf3(a: f16, b: f16) callconv(.C) f16 {
    return mulf3(f16, a, b);
}
