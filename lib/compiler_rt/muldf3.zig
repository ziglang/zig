const common = @import("./common.zig");
const mulf3 = @import("./mulf3.zig").mulf3;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_dmul, .{ .name = "__aeabi_dmul", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(__muldf3, .{ .name = "__muldf3", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __muldf3(a: f64, b: f64) callconv(.C) f64 {
    return mulf3(f64, a, b);
}

fn __aeabi_dmul(a: f64, b: f64) callconv(.AAPCS) f64 {
    return mulf3(f64, a, b);
}
