const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");

pub fn __fixunssfdi(a: f32) callconv(.C) u64 {
    @setRuntimeSafety(builtin.is_test);
    return fixuint(f32, u64, a);
}

test "import fixunssfdi" {
    _ = @import("fixunssfdi_test.zig");
}
