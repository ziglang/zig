const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    @export(__floatundihf, .{ .name = "__floatundihf", .linkage = common.linkage });
}

fn __floatundihf(a: u64) callconv(.C) f16 {
    return intToFloat(f16, a);
}
