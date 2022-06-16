const common = @import("./common.zig");
const truncf = @import("./truncf.zig").truncf;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__trunckfsf2, .{ .name = "__trunckfsf2", .linkage = common.linkage });
    } else {
        @export(__trunctfsf2, .{ .name = "__trunctfsf2", .linkage = common.linkage });
    }
}

fn __trunctfsf2(a: f128) callconv(.C) f32 {
    return truncf(f32, f128, a);
}

fn __trunckfsf2(a: f128) callconv(.C) f32 {
    return truncf(f32, f128, a);
}
