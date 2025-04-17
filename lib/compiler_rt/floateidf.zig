const std = @import("std");
const builtin = @import("builtin");
const common = @import("common.zig");
const floatFromBigInt = @import("float_from_int.zig").floatFromBigInt;

pub const panic = common.panic;

comptime {
    @export(&__floateidf, .{ .name = "__floateidf", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __floateidf(a: [*]const u8, bits: usize) callconv(.c) f64 {
    const byte_size = std.zig.target.intByteSize(builtin.target, @intCast(bits));
    return floatFromBigInt(f64, .signed, @ptrCast(@alignCast(a[0..byte_size])));
}
