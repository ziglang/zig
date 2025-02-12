const divCeil = @import("std").math.divCeil;
const common = @import("./common.zig");
const floatFromBigInt = @import("./float_from_int.zig").floatFromBigInt;

pub const panic = common.panic;

comptime {
    @export(&__floatuneitf, .{ .name = "__floatuneitf", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __floatuneitf(a: [*]const u32, bits: usize) callconv(.c) f128 {
    return floatFromBigInt(f128, .unsigned, a[0 .. divCeil(usize, bits, 32) catch unreachable]);
}
