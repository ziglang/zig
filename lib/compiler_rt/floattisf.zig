const builtin = @import("builtin");
const common = @import("./common.zig");
const floatFromInt = @import("./float_from_int.zig").floatFromInt;

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(&__floattisf_windows_x86_64, .{ .name = "__floattisf", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(&__floattisf, .{ .name = "__floattisf", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __floattisf(a: i128) callconv(.C) f32 {
    return floatFromInt(f32, a);
}

fn __floattisf_windows_x86_64(a: @Vector(2, u64)) callconv(.C) f32 {
    return floatFromInt(f32, @as(i128, @bitCast(a)));
}
