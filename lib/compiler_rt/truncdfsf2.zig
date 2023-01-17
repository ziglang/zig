const common = @import("./common.zig");
const truncf = @import("./truncf.zig").truncf;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_d2f, .{ .name = "__aeabi_d2f", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(__truncdfsf2, .{ .name = "__truncdfsf2", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __truncdfsf2(a: f64) callconv(.C) f32 {
    return truncf(f32, f64, a);
}

fn __aeabi_d2f(a: f64) callconv(.AAPCS) f32 {
    return truncf(f32, f64, a);
}
