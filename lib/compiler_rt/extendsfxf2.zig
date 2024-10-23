const common = @import("./common.zig");
const extend_f80 = @import("./extendf.zig").extend_f80;

pub const panic = common.panic;

comptime {
    @export(&__extendsfxf2, .{ .name = "__extendsfxf2", .linkage = common.linkage, .visibility = common.visibility });
}

fn __extendsfxf2(a: f32) callconv(.C) f80 {
    return extend_f80(f32, @as(u32, @bitCast(a)));
}
