const builtin = @import("builtin");
const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    const symbol_name = if (common.want_ppc_abi) "__floatuntikf" else "__floatuntitf";

    if (common.want_windows_v2u64_abi) {
        @export(__floatuntitf_windows_x86_64, .{ .name = symbol_name, .linkage = common.linkage });
    } else {
        @export(__floatuntitf, .{ .name = symbol_name, .linkage = common.linkage });
    }
}

pub fn __floatuntitf(a: u128) callconv(.C) f128 {
    return intToFloat(f128, a);
}

fn __floatuntitf_windows_x86_64(a: @Vector(2, u64)) callconv(.C) f128 {
    return intToFloat(f128, @bitCast(u128, a));
}
