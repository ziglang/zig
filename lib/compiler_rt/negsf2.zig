const common = @import("./common.zig");

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_fneg, .{ .name = "__aeabi_fneg", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(__negsf2, .{ .name = "__negsf2", .linkage = common.linkage, .visibility = common.visibility });
    }
}

fn __negsf2(a: f32) callconv(.C) f32 {
    return common.fneg(a);
}

fn __aeabi_fneg(a: f32) callconv(.AAPCS) f32 {
    return common.fneg(a);
}
