const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");

pub extern fn __fixunssfsi(a: f32) -> u32 {
    @setDebugSafety(this, builtin.is_test);
    return fixuint(f32, u32, a);
}

test "import fixunssfsi" {
    _ = @import("fixunssfsi_test.zig");
}
