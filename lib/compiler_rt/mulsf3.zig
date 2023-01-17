const common = @import("./common.zig");
const mulf3 = @import("./mulf3.zig").mulf3;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_fmul, .{ .name = "__aeabi_fmul", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(__mulsf3, .{ .name = "__mulsf3", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __mulsf3(a: f32, b: f32) callconv(.C) f32 {
    return mulf3(f32, a, b);
}

fn __aeabi_fmul(a: f32, b: f32) callconv(.AAPCS) f32 {
    return mulf3(f32, a, b);
}
