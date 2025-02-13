const divCeil = @import("std").math.divCeil;
const common = @import("./common.zig");
const floatFromBigInt = @import("./float_from_int.zig").floatFromBigInt;

pub const panic = common.panic;

comptime {
    @export(&__floateitf, .{ .name = "__floateitf", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __floateitf(a: [*]const u32, bits: usize) callconv(.c) f128 {
    return floatFromBigInt(f128, .signed, a[0 .. divCeil(usize, bits, 32) catch unreachable]);
}
