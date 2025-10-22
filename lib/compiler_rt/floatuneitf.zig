const std = @import("std");
const builtin = @import("builtin");
const common = @import("common.zig");
const floatFromBigInt = @import("float_from_int.zig").floatFromBigInt;

pub const panic = common.panic;

comptime {
    @export(&__floatuneitf, .{ .name = "__floatuneitf", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __floatuneitf(a: [*]const u8, bits: usize) callconv(.c) f128 {
    const byte_size = std.zig.target.intByteSize(&builtin.target, @intCast(bits));
    return floatFromBigInt(f128, .unsigned, @ptrCast(@alignCast(a[0..byte_size])));
}
