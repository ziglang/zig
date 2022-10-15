const common = @import("./common.zig");
const extendf = @import("./extendf.zig").extendf;

pub const panic = common.panic;

comptime {
    @export(__extendhfdf2, .{ .name = "__extendhfdf2", .linkage = common.linkage });
}

pub fn __extendhfdf2(a: common.F16T) callconv(.C) f64 {
    return extendf(f64, f16, @bitCast(u16, a));
}
