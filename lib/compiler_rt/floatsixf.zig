const common = @import("./common.zig");
const floatFromInt = @import("./float_from_int.zig").floatFromInt;

pub const panic = common.panic;

comptime {
    @export(&__floatsixf, .{ .name = "__floatsixf", .linkage = common.linkage, .visibility = common.visibility });
}

fn __floatsixf(a: i32) callconv(.C) f80 {
    return floatFromInt(f80, a);
}
