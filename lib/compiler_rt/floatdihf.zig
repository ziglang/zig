const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    @export(__floatdihf, .{ .name = "__floatdihf", .linkage = common.linkage });
}

fn __floatdihf(a: i64) callconv(.C) f16 {
    return intToFloat(f16, a);
}
