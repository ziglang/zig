const builtin = @import("builtin");
const common = @import("./common.zig");
const floatFromInt = @import("./float_from_int.zig").floatFromInt;

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(__floatuntihf_windows_x86_64, .{ .name = "__floatuntihf", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(__floatuntihf, .{ .name = "__floatuntihf", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __floatuntihf(a: u128) callconv(.C) f16 {
    return floatFromInt(f16, a);
}

fn __floatuntihf_windows_x86_64(a: @Vector(2, u64)) callconv(.C) f16 {
    return floatFromInt(f16, @bitCast(u128, a));
}
