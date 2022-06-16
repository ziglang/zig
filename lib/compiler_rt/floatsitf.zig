const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__floatsikf, .{ .name = "__floatsikf", .linkage = common.linkage });
    } else {
        @export(__floatsitf, .{ .name = "__floatsitf", .linkage = common.linkage });
    }
}

fn __floatsitf(a: i32) callconv(.C) f128 {
    return intToFloat(f128, a);
}

fn __floatsikf(a: i32) callconv(.C) f128 {
    return intToFloat(f128, a);
}
