const common = @import("./common.zig");
const floatFromInt = @import("./float_from_int.zig").floatFromInt;

pub const panic = common.panic;

comptime {
    @export(&__floatunsihf, .{ .name = "__floatunsihf", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __floatunsihf(a: u32) callconv(.C) f16 {
    return floatFromInt(f16, a);
}
