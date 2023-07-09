const common = @import("./common.zig");
const intFromFloat = @import("./int_from_float.zig").intFromFloat;

pub const panic = common.panic;

comptime {
    @export(__fixhfsi, .{ .name = "__fixhfsi", .linkage = common.linkage, .visibility = common.visibility });
}

fn __fixhfsi(a: f16) callconv(.C) i32 {
    return intFromFloat(i32, a);
}
