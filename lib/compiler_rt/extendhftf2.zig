const common = @import("./common.zig");
const extendf = @import("./extendf.zig").extendf;

pub const panic = common.panic;

comptime {
    @export(__extendhftf2, .{ .name = "__extendhftf2", .linkage = common.linkage });
}

pub fn __extendhftf2(a: common.F16T) callconv(.C) f128 {
    return extendf(f128, f16, @bitCast(u16, a));
}
