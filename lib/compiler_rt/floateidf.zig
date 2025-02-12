const divCeil = @import("std").math.divCeil;
const common = @import("./common.zig");
const floatFromBigInt = @import("./float_from_int.zig").floatFromBigInt;

pub const panic = common.panic;

comptime {
    @export(&__floateidf, .{ .name = "__floateidf", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __floateidf(a: [*]const u32, bits: usize) callconv(.c) f64 {
    return floatFromBigInt(f64, .signed, a[0 .. divCeil(usize, bits, 32) catch unreachable]);
}
