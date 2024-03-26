const common = @import("./common.zig");
const extendf = @import("./extendf.zig").extendf;

pub const panic = common.panic;

comptime {
    @export(&__extendhfdf2, .{ .name = "__extendhfdf2", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __extendhfdf2(a: common.F16T(f64)) callconv(.C) f64 {
    return extendf(f64, f16, @as(u16, @bitCast(a)));
}
