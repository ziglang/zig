const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    @export(__fixdfti, .{ .name = "__fixdfti", .linkage = common.linkage });
}

pub fn __fixdfti(a: f64) callconv(.C) i128 {
    return floatToInt(i128, a);
}
