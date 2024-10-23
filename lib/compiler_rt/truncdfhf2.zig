const common = @import("./common.zig");
const truncf = @import("./truncf.zig").truncf;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(&__aeabi_d2h, .{ .name = "__aeabi_d2h", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(&__truncdfhf2, .{ .name = "__truncdfhf2", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __truncdfhf2(a: f64) callconv(.C) common.F16T(f64) {
    return @bitCast(truncf(f16, f64, a));
}

fn __aeabi_d2h(a: f64) callconv(.AAPCS) u16 {
    return @bitCast(truncf(f16, f64, a));
}
