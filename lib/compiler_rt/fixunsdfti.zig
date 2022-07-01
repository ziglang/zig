const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    @export(__fixunsdfti, .{ .name = "__fixunsdfti", .linkage = common.linkage });
}

pub fn __fixunsdfti(a: f64) callconv(.C) u128 {
    return floatToInt(u128, a);
}
