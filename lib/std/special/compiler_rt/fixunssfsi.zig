const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");

pub fn __fixunssfsi(a: f32) callconv(.C) u32 {
    @setRuntimeSafety(builtin.is_test);
    return fixuint(f32, u32, a);
}

test "import fixunssfsi" {
    _ = @import("fixunssfsi_test.zig");
}
