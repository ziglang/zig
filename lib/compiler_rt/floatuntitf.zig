const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__floatuntikf, .{ .name = "__floatuntikf", .linkage = common.linkage });
    } else {
        @export(__floatuntitf, .{ .name = "__floatuntitf", .linkage = common.linkage });
    }
}

pub fn __floatuntitf(a: u128) callconv(.C) f128 {
    return intToFloat(f128, a);
}

fn __floatuntikf(a: u128) callconv(.C) f128 {
    return intToFloat(f128, a);
}
