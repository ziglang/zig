const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    @export(__fixxfti, .{ .name = "__fixxfti", .linkage = common.linkage });
}

fn __fixxfti(a: f80) callconv(.C) i128 {
    return floatToInt(i128, a);
}
