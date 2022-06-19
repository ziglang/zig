const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    @export(__fixhfti, .{ .name = "__fixhfti", .linkage = common.linkage });
}

fn __fixhfti(a: f16) callconv(.C) i128 {
    return floatToInt(i128, a);
}
