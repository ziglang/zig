const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    @export(__fixunstfti, .{ .name = "__fixunstfti", .linkage = common.linkage });
}

pub fn __fixunstfti(a: f128) callconv(.C) u128 {
    return floatToInt(u128, a);
}
