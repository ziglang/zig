const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    @export(__floattisf, .{ .name = "__floattisf", .linkage = common.linkage });
}

pub fn __floattisf(a: i128) callconv(.C) f32 {
    return intToFloat(f32, a);
}
