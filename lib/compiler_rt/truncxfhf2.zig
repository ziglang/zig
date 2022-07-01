const common = @import("./common.zig");
const trunc_f80 = @import("./truncf.zig").trunc_f80;

pub const panic = common.panic;

comptime {
    @export(__truncxfhf2, .{ .name = "__truncxfhf2", .linkage = common.linkage });
}

fn __truncxfhf2(a: f80) callconv(.C) common.F16T {
    return @bitCast(common.F16T, trunc_f80(f16, a));
}
