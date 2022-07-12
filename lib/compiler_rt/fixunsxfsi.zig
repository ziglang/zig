const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    if (common.should_emit_f80_or_f128) {
        @export(__fixunsxfsi, .{ .name = "__fixunsxfsi", .linkage = common.linkage });
    }
}

fn __fixunsxfsi(a: f80) callconv(.C) u32 {
    return floatToInt(u32, a);
}
