const common = @import("./common.zig");
const mulf3 = @import("./mulf3.zig").mulf3;

pub const panic = common.panic;

comptime {
    if (common.should_emit_f80_or_f128) {
        @export(__mulxf3, .{ .name = "__mulxf3", .linkage = common.linkage });
    }
}

pub fn __mulxf3(a: f80, b: f80) callconv(.C) f80 {
    return mulf3(f80, a, b);
}
