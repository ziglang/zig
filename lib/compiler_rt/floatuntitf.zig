const builtin = @import("builtin");
const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(__floatuntitf_windows_x86_64, .{ .name = "__floatuntitf", .linkage = common.linkage });
    } else {
        if (common.want_ppc_abi) {
            @export(__floatuntitf, .{ .name = "__floatuntikf", .linkage = common.linkage });
        }
        @export(__floatuntitf, .{ .name = "__floatuntitf", .linkage = common.linkage });
    }
}

pub fn __floatuntitf(a: u128) callconv(.C) f128 {
    return intToFloat(f128, a);
}

fn __floatuntitf_windows_x86_64(a: @Vector(2, u64)) callconv(.C) f128 {
    return intToFloat(f128, @bitCast(u128, a));
}
