const std = @import("std");
const fixint = @import("fixint.zig").fixint;
const builtin = std.builtin;

pub fn __fixsfti(a: f32) callconv(.C) i128 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f32, i128, a);
}

test "import fixsfti" {
    _ = @import("fixsfti_test.zig");
}
