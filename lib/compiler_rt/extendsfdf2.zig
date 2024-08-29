const common = @import("./common.zig");
const extendf = @import("./extendf.zig").extendf;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(&__aeabi_f2d, .{ .name = "__aeabi_f2d", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(&__extendsfdf2, .{ .name = "__extendsfdf2", .linkage = common.linkage, .visibility = common.visibility });
    }
}

fn __extendsfdf2(a: f32) callconv(.C) f64 {
    return extendf(f64, f32, @as(u32, @bitCast(a)));
}

fn __aeabi_f2d(a: f32) callconv(.AAPCS) f64 {
    return extendf(f64, f32, @as(u32, @bitCast(a)));
}
