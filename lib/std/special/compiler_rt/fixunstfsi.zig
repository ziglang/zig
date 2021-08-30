const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");

pub fn __fixunstfsi(a: f128) callconv(.C) u32 {
    @setRuntimeSafety(builtin.is_test);
    return fixuint(f128, u32, a);
}

test {
    _ = @import("fixunstfsi_test.zig");
}
