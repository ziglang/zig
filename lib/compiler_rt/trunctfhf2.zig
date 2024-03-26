const common = @import("./common.zig");
const truncf = @import("./truncf.zig").truncf;

pub const panic = common.panic;

comptime {
    @export(&__trunctfhf2, .{ .name = "__trunctfhf2", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __trunctfhf2(a: f128) callconv(.C) common.F16T(f128) {
    return @bitCast(truncf(f16, f128, a));
}
