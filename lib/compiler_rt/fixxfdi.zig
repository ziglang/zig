const common = @import("./common.zig");
const intFromFloat = @import("./int_from_float.zig").intFromFloat;

pub const panic = common.panic;

comptime {
    @export(__fixxfdi, .{ .name = "__fixxfdi", .linkage = common.linkage, .visibility = common.visibility });
}

fn __fixxfdi(a: f80) callconv(.C) i64 {
    return intFromFloat(i64, a);
}
