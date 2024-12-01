const common = @import("./common.zig");
const addf3 = @import("./addf3.zig").addf3;

pub const panic = common.panic;

comptime {
    @export(&__addxf3, .{ .name = "__addxf3", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __addxf3(a: f80, b: f80) callconv(.C) f80 {
    return addf3(f80, a, b);
}
