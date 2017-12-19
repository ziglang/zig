const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");

pub extern fn __fixunstfsi(a: f128) -> u32 {
    @setDebugSafety(this, builtin.is_test);
    return fixuint(f128, u32, a);
}

test "import fixunstfsi" {
    _ = @import("fixunstfsi_test.zig");
}
