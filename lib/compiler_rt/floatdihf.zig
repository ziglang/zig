const common = @import("./common.zig");
const floatFromInt = @import("./float_from_int.zig").floatFromInt;

pub const panic = common.panic;

comptime {
    @export(__floatdihf, .{ .name = "__floatdihf", .linkage = common.linkage, .visibility = common.visibility });
}

fn __floatdihf(a: i64) callconv(.C) f16 {
    return floatFromInt(f16, a);
}
