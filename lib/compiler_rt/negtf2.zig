const common = @import("./common.zig");

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi)
        @export(&__negtf2, .{ .name = "__negkf2", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__negtf2, .{ .name = "__negtf2", .linkage = common.linkage, .visibility = common.visibility });
}

fn __negtf2(a: f128) callconv(.C) f128 {
    return common.fneg(a);
}
