const common = @import("./common.zig");
const floatFromInt = @import("./float_from_int.zig").floatFromInt;

pub const panic = common.panic;

comptime {
    @export(__floatundihf, .{ .name = "__floatundihf", .linkage = common.linkage, .visibility = common.visibility });
}

fn __floatundihf(a: u64) callconv(.C) f16 {
    return floatFromInt(f16, a);
}
