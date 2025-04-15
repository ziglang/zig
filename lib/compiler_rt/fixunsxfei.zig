const std = @import("std");
const builtin = @import("builtin");
const common = @import("common.zig");
const bigIntFromFloat = @import("int_from_float.zig").bigIntFromFloat;

pub const panic = common.panic;

comptime {
    @export(&__fixunsxfei, .{ .name = "__fixunsxfei", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __fixunsxfei(r: [*]u8, bits: usize, a: f80) callconv(.c) void {
    const byte_size = std.zig.target.intByteSize(builtin.target, @intCast(bits));
    return bigIntFromFloat(.unsigned, @ptrCast(@alignCast(r[0..byte_size])), a);
}
