const builtin = @import("builtin");
const common = @import("./common.zig");
const floatFromInt = @import("./float_from_int.zig").floatFromInt;

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(__floattitf_windows_x86_64, .{ .name = "__floattitf", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        if (common.want_ppc_abi)
            @export(__floattitf, .{ .name = "__floattikf", .linkage = common.linkage, .visibility = common.visibility });
        @export(__floattitf, .{ .name = "__floattitf", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __floattitf(a: i128) callconv(.C) f128 {
    return floatFromInt(f128, a);
}

fn __floattitf_windows_x86_64(a: @Vector(2, u64)) callconv(.C) f128 {
    return floatFromInt(f128, @as(i128, @bitCast(a)));
}
