const fixint = @import("fixint.zig").fixint;
const builtin = @import("builtin");

pub fn __fixsfdi(a: f32) callconv(.C) i64 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f32, i64, a);
}

test "import fixsfdi" {
    _ = @import("fixsfdi_test.zig");
}
