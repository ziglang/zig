const common = @import("./common.zig");
const comparef = @import("./comparef.zig");

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(&__aeabi_fcmpun, .{ .name = "__aeabi_fcmpun", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(&__unordsf2, .{ .name = "__unordsf2", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __unordsf2(a: f32, b: f32) callconv(.C) i32 {
    return comparef.unordcmp(f32, a, b);
}

fn __aeabi_fcmpun(a: f32, b: f32) callconv(.AAPCS) i32 {
    return comparef.unordcmp(f32, a, b);
}
