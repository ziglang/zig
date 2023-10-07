const common = @import("./common.zig");
const intFromFloat = @import("./int_from_float.zig").intFromFloat;

pub const panic = common.panic;

comptime {
    @export(__fixhfdi, .{ .name = "__fixhfdi", .linkage = common.linkage, .visibility = common.visibility });
}

fn __fixhfdi(a: f16) callconv(.C) i64 {
    return intFromFloat(i64, a);
}
