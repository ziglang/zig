const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    @export(__fixtfti, .{ .name = "__fixtfti", .linkage = common.linkage });
}

pub fn __fixtfti(a: f128) callconv(.C) i128 {
    return floatToInt(i128, a);
}
