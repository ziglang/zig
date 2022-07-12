const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    if (common.should_emit_f80_or_f128) {
        @export(__fixxfsi, .{ .name = "__fixxfsi", .linkage = common.linkage });
    }
}

fn __fixxfsi(a: f80) callconv(.C) i32 {
    return floatToInt(i32, a);
}
