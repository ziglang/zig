const common = @import("./common.zig");
const extend_f80 = @import("./extendf.zig").extend_f80;

pub const panic = common.panic;

comptime {
    if (common.should_emit_f80_or_f128) {
        @export(__extenddfxf2, .{ .name = "__extenddfxf2", .linkage = common.linkage });
    }
}

fn __extenddfxf2(a: f64) callconv(.C) f80 {
    return extend_f80(f64, @bitCast(u64, a));
}
