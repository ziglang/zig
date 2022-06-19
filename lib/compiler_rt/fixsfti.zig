const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    @export(__fixsfti, .{ .name = "__fixsfti", .linkage = common.linkage });
}

pub fn __fixsfti(a: f32) callconv(.C) i128 {
    return floatToInt(i128, a);
}
