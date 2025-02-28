const common = @import("./common.zig");
const floatFromInt = @import("./float_from_int.zig").floatFromInt;

pub const panic = common.panic;

comptime {
    @export(&__floatsihf, .{ .name = "__floatsihf", .linkage = common.linkage, .visibility = common.visibility });
}

fn __floatsihf(a: i32) callconv(.C) f16 {
    return floatFromInt(f16, a);
}
