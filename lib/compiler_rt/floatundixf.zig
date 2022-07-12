const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    if (common.should_emit_f80_or_f128) {
        @export(__floatundixf, .{ .name = "__floatundixf", .linkage = common.linkage });
    }
}

fn __floatundixf(a: u64) callconv(.C) f80 {
    return intToFloat(f80, a);
}
