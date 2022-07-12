const common = @import("./common.zig");
const extend_f80 = @import("./extendf.zig").extend_f80;

pub const panic = common.panic;

comptime {
    if (common.should_emit_f80_or_f128) {
        @export(__extendsfxf2, .{ .name = "__extendsfxf2", .linkage = common.linkage });
    }
}

fn __extendsfxf2(a: f32) callconv(.C) f80 {
    return extend_f80(f32, @bitCast(u32, a));
}
