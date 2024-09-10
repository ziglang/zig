const common = @import("./common.zig");
const comparef = @import("./comparef.zig");

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(&__aeabi_dcmpun, .{ .name = "__aeabi_dcmpun", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(&__unorddf2, .{ .name = "__unorddf2", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __unorddf2(a: f64, b: f64) callconv(.C) i32 {
    return comparef.unordcmp(f64, a, b);
}

fn __aeabi_dcmpun(a: f64, b: f64) callconv(.AAPCS) i32 {
    return comparef.unordcmp(f64, a, b);
}
