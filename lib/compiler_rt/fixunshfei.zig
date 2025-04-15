const std = @import("std");
const builtin = @import("builtin");
const common = @import("common.zig");
const bigIntFromFloat = @import("int_from_float.zig").bigIntFromFloat;

pub const panic = common.panic;

comptime {
    @export(&__fixunshfei, .{ .name = "__fixunshfei", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __fixunshfei(r: [*]u8, bits: usize, a: f16) callconv(.c) void {
    const byte_size = std.zig.target.intByteSize(builtin.target, @intCast(bits));
    return bigIntFromFloat(.unsigned, @ptrCast(@alignCast(r[0..byte_size])), a);
}
