const common = @import("./common.zig");
const intToFloat = @import("./int_to_float.zig").intToFloat;

pub const panic = common.panic;

comptime {
    if (common.should_emit_f80_or_f128) {
        @export(__floatunsixf, .{ .name = "__floatunsixf", .linkage = common.linkage });
    }
}

fn __floatunsixf(a: u32) callconv(.C) f80 {
    return intToFloat(f80, a);
}
