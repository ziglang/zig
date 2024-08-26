const common = @import("./common.zig");
const intFromFloat = @import("./int_from_float.zig").intFromFloat;

pub const panic = common.panic;

comptime {
    @export(&__fixxfsi, .{ .name = "__fixxfsi", .linkage = common.linkage, .visibility = common.visibility });
}

fn __fixxfsi(a: f80) callconv(.C) i32 {
    return intFromFloat(i32, a);
}
