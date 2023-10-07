const builtin = @import("builtin");
const common = @import("./common.zig");
const floatFromInt = @import("./float_from_int.zig").floatFromInt;

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(__floatuntitf_windows_x86_64, .{ .name = "__floatuntitf", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        if (common.want_ppc_abi)
            @export(__floatuntitf, .{ .name = "__floatuntikf", .linkage = common.linkage, .visibility = common.visibility });
        @export(__floatuntitf, .{ .name = "__floatuntitf", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __floatuntitf(a: u128) callconv(.C) f128 {
    return floatFromInt(f128, a);
}

fn __floatuntitf_windows_x86_64(a: @Vector(2, u64)) callconv(.C) f128 {
    return floatFromInt(f128, @as(u128, @bitCast(a)));
}
