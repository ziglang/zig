const common = @import("./common.zig");
const addf3 = @import("./addf3.zig").addf3;

pub const panic = common.panic;

comptime {
    @export(&__addhf3, .{ .name = "__addhf3", .linkage = common.linkage, .visibility = common.visibility });
}

fn __addhf3(a: f16, b: f16) callconv(.C) f16 {
    return addf3(f16, a, b);
}
