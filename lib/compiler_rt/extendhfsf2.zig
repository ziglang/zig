const common = @import("./common.zig");
const extendf = @import("./extendf.zig").extendf;

pub const panic = common.panic;

comptime {
    if (common.gnu_f16_abi) {
        @export(&__gnu_h2f_ieee, .{ .name = "__gnu_h2f_ieee", .linkage = common.linkage, .visibility = common.visibility });
    } else if (common.want_aeabi) {
        @export(&__aeabi_h2f, .{ .name = "__aeabi_h2f", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(&__extendhfsf2, .{ .name = "__extendhfsf2", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __extendhfsf2(a: common.F16T(f32)) callconv(.C) f32 {
    return extendf(f32, f16, @as(u16, @bitCast(a)));
}

fn __gnu_h2f_ieee(a: common.F16T(f32)) callconv(.C) f32 {
    return extendf(f32, f16, @as(u16, @bitCast(a)));
}

fn __aeabi_h2f(a: u16) callconv(.AAPCS) f32 {
    return extendf(f32, f16, @as(u16, @bitCast(a)));
}
