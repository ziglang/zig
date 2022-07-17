const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    @export(__floatunsihf, .{ .name = "__floatunsihf", .linkage = common.linkage });
}

pub fn __floatunsihf(a: u32) callconv(.C) f16 {
    return intToFloat(f16, a);
}
