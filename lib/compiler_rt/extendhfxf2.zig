const common = @import("./common.zig");
const extend_f80 = @import("./extendf.zig").extend_f80;

pub const panic = common.panic;

comptime {
    @export(__extendhfxf2, .{ .name = "__extendhfxf2", .linkage = common.linkage });
}

fn __extendhfxf2(a: common.F16T) callconv(.C) f80 {
    return extend_f80(f16, @bitCast(u16, a));
}
