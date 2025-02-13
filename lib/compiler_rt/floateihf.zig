const divCeil = @import("std").math.divCeil;
const common = @import("./common.zig");
const floatFromBigInt = @import("./float_from_int.zig").floatFromBigInt;

pub const panic = common.panic;

comptime {
    @export(&__floateihf, .{ .name = "__floateihf", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __floateihf(a: [*]const u32, bits: usize) callconv(.c) f16 {
    return floatFromBigInt(f16, .signed, a[0 .. divCeil(usize, bits, 32) catch unreachable]);
}
