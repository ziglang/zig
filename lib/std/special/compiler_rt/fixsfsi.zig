const std = @import("std");
const fixint = @import("fixint.zig").fixint;
const builtin = std.builtin;

pub fn __fixsfsi(a: f32) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f32, i32, a);
}

pub fn __aeabi_f2iz(a: f32) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __fixsfsi, .{a});
}

test "import fixsfsi" {
    _ = @import("fixsfsi_test.zig");
}
