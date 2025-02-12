const divCeil = @import("std").math.divCeil;
const common = @import("./common.zig");
const floatFromBigInt = @import("./float_from_int.zig").floatFromBigInt;

pub const panic = common.panic;

comptime {
    @export(&__floatuneixf, .{ .name = "__floatuneixf", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __floatuneixf(a: [*]const u32, bits: usize) callconv(.c) f80 {
    return floatFromBigInt(f80, .unsigned, a[0 .. divCeil(usize, bits, 32) catch unreachable]);
}
