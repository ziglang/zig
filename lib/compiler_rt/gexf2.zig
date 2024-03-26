const common = @import("./common.zig");
const comparef = @import("./comparef.zig");

pub const panic = common.panic;

comptime {
    @export(&__gexf2, .{ .name = "__gexf2", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__gtxf2, .{ .name = "__gtxf2", .linkage = common.linkage, .visibility = common.visibility });
}

fn __gexf2(a: f80, b: f80) callconv(.C) i32 {
    return @intFromEnum(comparef.cmp_f80(comparef.GE, a, b));
}

fn __gtxf2(a: f80, b: f80) callconv(.C) i32 {
    return __gexf2(a, b);
}
