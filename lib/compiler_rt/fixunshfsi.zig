const common = @import("./common.zig");
const intFromFloat = @import("./int_from_float.zig").intFromFloat;

pub const panic = common.panic;

comptime {
    @export(__fixunshfsi, .{ .name = "__fixunshfsi", .linkage = common.linkage, .visibility = common.visibility });
}

fn __fixunshfsi(a: f16) callconv(.C) u32 {
    return intFromFloat(u32, a);
}
