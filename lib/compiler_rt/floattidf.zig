const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    @export(__floattidf, .{ .name = "__floattidf", .linkage = common.linkage });
}

pub fn __floattidf(a: i128) callconv(.C) f64 {
    return intToFloat(f64, a);
}
