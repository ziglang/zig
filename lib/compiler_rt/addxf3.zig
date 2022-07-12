const common = @import("./common.zig");
const addf3 = @import("./addf3.zig").addf3;

pub const panic = common.panic;

comptime {
    if (common.should_emit_f80_or_f128) {
        @export(__addxf3, .{ .name = "__addxf3", .linkage = common.linkage });
    }
}

pub fn __addxf3(a: f80, b: f80) callconv(.C) f80 {
    return addf3(f80, a, b);
}
