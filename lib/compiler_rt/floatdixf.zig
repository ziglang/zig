const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    @export(__floatdixf, .{ .name = "__floatdixf", .linkage = common.linkage });
}

fn __floatdixf(a: i64) callconv(.C) f80 {
    return intToFloat(f80, a);
}
