const common = @import("./common.zig");
const trunc_f80 = @import("./truncf.zig").trunc_f80;

pub const panic = common.panic;

comptime {
    @export(__truncxfsf2, .{ .name = "__truncxfsf2", .linkage = common.linkage, .visibility = common.visibility });
}

fn __truncxfsf2(a: f80) callconv(.C) f32 {
    return trunc_f80(f32, a);
}
