const common = @import("./common.zig");
const intFromFloat = @import("./int_from_float.zig").intFromFloat;

pub const panic = common.panic;

comptime {
    @export(__fixunsxfsi, .{ .name = "__fixunsxfsi", .linkage = common.linkage, .visibility = common.visibility });
}

fn __fixunsxfsi(a: f80) callconv(.C) u32 {
    return intFromFloat(u32, a);
}
