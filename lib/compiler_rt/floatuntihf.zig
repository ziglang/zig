const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    @export(__floatuntihf, .{ .name = "__floatuntihf", .linkage = common.linkage });
}

fn __floatuntihf(a: u128) callconv(.C) f16 {
    return intToFloat(f16, a);
}
