const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    @export(__floatuntisf, .{ .name = "__floatuntisf", .linkage = common.linkage });
}

pub fn __floatuntisf(a: u128) callconv(.C) f32 {
    return intToFloat(f32, a);
}
