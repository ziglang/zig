const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");
const linkage = @import("index.zig").linkage;

export fn __fixunssfdi(a: f32) -> u64 {
    @setDebugSafety(this, builtin.is_test);
    @setGlobalLinkage(__fixunssfdi, linkage);
    return fixuint(f32, u64, a);
}

test "import fixunssfdi" {
    _ = @import("fixunssfdi_test.zig");
}
