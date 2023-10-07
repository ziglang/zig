const common = @import("./common.zig");
const floatFromInt = @import("./float_from_int.zig").floatFromInt;

pub const panic = common.panic;

comptime {
    @export(__floatundixf, .{ .name = "__floatundixf", .linkage = common.linkage, .visibility = common.visibility });
}

fn __floatundixf(a: u64) callconv(.C) f80 {
    return floatFromInt(f80, a);
}
