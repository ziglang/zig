const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    @export(__floatsixf, .{ .name = "__floatsixf", .linkage = common.linkage });
}

fn __floatsixf(a: i32) callconv(.C) f80 {
    return intToFloat(f80, a);
}
