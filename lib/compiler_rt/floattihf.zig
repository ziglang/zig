const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    @export(__floattihf, .{ .name = "__floattihf", .linkage = common.linkage });
}

fn __floattihf(a: i128) callconv(.C) f16 {
    return intToFloat(f16, a);
}
