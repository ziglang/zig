const common = @import("./common.zig");
const truncf = @import("./truncf.zig").truncf;

pub const panic = common.panic;

comptime {
    if (common.gnu_f16_abi) {
        @export(&__gnu_f2h_ieee, .{ .name = "__gnu_f2h_ieee", .linkage = common.linkage, .visibility = common.visibility });
    } else if (common.want_aeabi) {
        @export(&__aeabi_f2h, .{ .name = "__aeabi_f2h", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(&__truncsfhf2, .{ .name = "__truncsfhf2", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __truncsfhf2(a: f32) callconv(.C) common.F16T(f32) {
    return @bitCast(truncf(f16, f32, a));
}

fn __gnu_f2h_ieee(a: f32) callconv(.C) common.F16T(f32) {
    return @bitCast(truncf(f16, f32, a));
}

fn __aeabi_f2h(a: f32) callconv(.AAPCS) u16 {
    return @bitCast(truncf(f16, f32, a));
}
