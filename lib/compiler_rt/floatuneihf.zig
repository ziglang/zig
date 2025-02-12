const divCeil = @import("std").math.divCeil;
const common = @import("./common.zig");
const floatFromBigInt = @import("./float_from_int.zig").floatFromBigInt;

pub const panic = common.panic;

comptime {
    @export(&__floatuneihf, .{ .name = "__floatuneihf", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __floatuneihf(a: [*]const u32, bits: usize) callconv(.c) f16 {
    return floatFromBigInt(f16, .unsigned, a[0 .. divCeil(usize, bits, 32) catch unreachable]);
}
