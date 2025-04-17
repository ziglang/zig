const common = @import("./common.zig");

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(&__aeabi_dneg, .{ .name = "__aeabi_dneg", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(&__negdf2, .{ .name = "__negdf2", .linkage = common.linkage, .visibility = common.visibility });
    }
}

fn __negdf2(a: f64) callconv(.c) f64 {
    return common.fneg(a);
}

fn __aeabi_dneg(a: f64) callconv(.{ .arm_aapcs = .{} }) f64 {
    return common.fneg(a);
}
