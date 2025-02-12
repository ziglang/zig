const divCeil = @import("std").math.divCeil;
const common = @import("./common.zig");
const floatFromBigInt = @import("./float_from_int.zig").floatFromBigInt;

pub const panic = common.panic;

comptime {
    @export(&__floateisf, .{ .name = "__floateisf", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __floateisf(a: [*]const u32, bits: usize) callconv(.c) f32 {
    return floatFromBigInt(f32, .signed, a[0 .. divCeil(usize, bits, 32) catch unreachable]);
}
