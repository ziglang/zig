const fixint = @import("fixint.zig").fixint;
const builtin = @import("builtin");

pub extern fn __fixsfsi(a: f32) i32 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f32, i32, a);
}

test "import fixsfsi" {
    _ = @import("fixsfsi_test.zig");
}
