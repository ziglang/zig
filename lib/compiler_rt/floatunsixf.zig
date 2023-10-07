const common = @import("./common.zig");
const floatFromInt = @import("./float_from_int.zig").floatFromInt;

pub const panic = common.panic;

comptime {
    @export(__floatunsixf, .{ .name = "__floatunsixf", .linkage = common.linkage, .visibility = common.visibility });
}

fn __floatunsixf(a: u32) callconv(.C) f80 {
    return floatFromInt(f80, a);
}
