const divCeil = @import("std").math.divCeil;
const common = @import("./common.zig");
const floatFromBigInt = @import("./float_from_int.zig").floatFromBigInt;

pub const panic = common.panic;

comptime {
    @export(&__floatuneidf, .{ .name = "__floatuneidf", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __floatuneidf(a: [*]const u32, bits: usize) callconv(.c) f64 {
    return floatFromBigInt(f64, .unsigned, a[0 .. divCeil(usize, bits, 32) catch unreachable]);
}
