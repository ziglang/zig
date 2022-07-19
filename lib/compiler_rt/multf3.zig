const common = @import("./common.zig");
const mulf3 = @import("./mulf3.zig").mulf3;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__mulkf3, .{ .name = "__mulkf3", .linkage = common.linkage });
    } else {
        @export(__multf3, .{ .name = "__multf3", .linkage = common.linkage });
    }
}

fn __multf3(a: f128, b: f128) callconv(.C) f128 {
    return mulf3(f128, a, b);
}

fn __mulkf3(a: f128, b: f128) callconv(.C) f128 {
    return mulf3(f128, a, b);
}
