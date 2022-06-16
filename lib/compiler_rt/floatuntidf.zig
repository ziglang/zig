const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    @export(__floatuntidf, .{ .name = "__floatuntidf", .linkage = common.linkage });
}

pub fn __floatuntidf(a: u128) callconv(.C) f64 {
    return intToFloat(f64, a);
}
