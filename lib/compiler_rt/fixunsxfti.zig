const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    @export(__fixunsxfti, .{ .name = "__fixunsxfti", .linkage = common.linkage });
}

pub fn __fixunsxfti(a: f80) callconv(.C) u128 {
    return floatToInt(u128, a);
}
