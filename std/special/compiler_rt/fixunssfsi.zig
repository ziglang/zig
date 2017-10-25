const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");
const linkage = @import("index.zig").linkage;

export fn __fixunssfsi(a: f32) -> u32 {
    @setDebugSafety(this, builtin.is_test);
    @setGlobalLinkage(__fixunssfsi, linkage);
    return fixuint(f32, u32, a);
}

test "import fixunssfsi" {
    _ = @import("fixunssfsi_test.zig");
}
