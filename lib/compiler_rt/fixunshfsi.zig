const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    @export(__fixunshfsi, .{ .name = "__fixunshfsi", .linkage = common.linkage });
}

fn __fixunshfsi(a: f16) callconv(.C) u32 {
    return floatToInt(u32, a);
}
