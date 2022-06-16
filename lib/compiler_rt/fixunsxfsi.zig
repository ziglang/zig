const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    @export(__fixunsxfsi, .{ .name = "__fixunsxfsi", .linkage = common.linkage });
}

fn __fixunsxfsi(a: f80) callconv(.C) u32 {
    return floatToInt(u32, a);
}
