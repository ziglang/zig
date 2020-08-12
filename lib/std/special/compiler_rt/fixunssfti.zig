const std = @import("std");
const fixuint = @import("fixuint.zig").fixuint;
const builtin = std.builtin;

pub fn __fixunssfti(a: f32) callconv(.C) u128 {
    @setRuntimeSafety(builtin.is_test);
    return fixuint(f32, u128, a);
}

test "import fixunssfti" {
    _ = @import("fixunssfti_test.zig");
}
