const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    @export(__floatsihf, .{ .name = "__floatsihf", .linkage = common.linkage });
}

fn __floatsihf(a: i32) callconv(.C) f16 {
    return intToFloat(f16, a);
}
