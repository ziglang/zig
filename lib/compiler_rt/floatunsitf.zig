const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__floatunsikf, .{ .name = "__floatunsikf", .linkage = common.linkage });
    } else {
        @export(__floatunsitf, .{ .name = "__floatunsitf", .linkage = common.linkage });
    }
}

fn __floatunsitf(a: u32) callconv(.C) f128 {
    return intToFloat(f128, a);
}

fn __floatunsikf(a: u32) callconv(.C) f128 {
    return intToFloat(f128, a);
}
