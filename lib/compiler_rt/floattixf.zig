const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    @export(__floattixf, .{ .name = "__floattixf", .linkage = common.linkage });
}

fn __floattixf(a: i128) callconv(.C) f80 {
    return intToFloat(f80, a);
}
