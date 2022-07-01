const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    @export(__floatuntixf, .{ .name = "__floatuntixf", .linkage = common.linkage });
}

pub fn __floatuntixf(a: u128) callconv(.C) f80 {
    return intToFloat(f80, a);
}
