const common = @import("./common.zig");
const trunc_f80 = @import("./truncf.zig").trunc_f80;

pub const panic = common.panic;

comptime {
    @export(__truncxfdf2, .{ .name = "__truncxfdf2", .linkage = common.linkage, .visibility = common.visibility });
}

fn __truncxfdf2(a: f80) callconv(.C) f64 {
    return trunc_f80(f64, a);
}
