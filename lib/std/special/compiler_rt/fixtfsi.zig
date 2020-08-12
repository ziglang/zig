const std = @import("std");
const fixint = @import("fixint.zig").fixint;
const builtin = std.builtin;

pub fn __fixtfsi(a: f128) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f128, i32, a);
}

test "import fixtfsi" {
    _ = @import("fixtfsi_test.zig");
}
