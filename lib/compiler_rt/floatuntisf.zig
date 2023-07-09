const builtin = @import("builtin");
const common = @import("./common.zig");
const floatFromInt = @import("./float_from_int.zig").floatFromInt;

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(__floatuntisf_windows_x86_64, .{ .name = "__floatuntisf", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(__floatuntisf, .{ .name = "__floatuntisf", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __floatuntisf(a: u128) callconv(.C) f32 {
    return floatFromInt(f32, a);
}

fn __floatuntisf_windows_x86_64(a: @Vector(2, u64)) callconv(.C) f32 {
    return floatFromInt(f32, @as(u128, @bitCast(a)));
}
