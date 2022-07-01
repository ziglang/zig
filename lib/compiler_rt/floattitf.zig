const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    @export(__floattitf, .{ .name = "__floattitf", .linkage = common.linkage });
}

pub fn __floattitf(a: i128) callconv(.C) f128 {
    return intToFloat(f128, a);
}
