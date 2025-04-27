const std = @import("std");
const builtin = @import("builtin");
const common = @import("common.zig");
const floatFromBigInt = @import("float_from_int.zig").floatFromBigInt;

pub const panic = common.panic;

comptime {
    @export(&__floateitf, .{ .name = "__floateitf", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __floateitf(a: [*]const u8, bits: usize) callconv(.c) f128 {
    const byte_size = std.zig.target.intByteSize(builtin.target, @intCast(bits));
    return floatFromBigInt(f128, .signed, @ptrCast(@alignCast(a[0..byte_size])));
}
