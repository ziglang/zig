const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");
const linkage = if (builtin.is_test) builtin.GlobalLinkage.Internal else builtin.GlobalLinkage.LinkOnce;

export fn __fixunssfsi(a: f32) -> u32 {
    @setDebugSafety(this, builtin.is_test);
    @setGlobalLinkage(__fixunssfsi, linkage);
    return fixuint(f32, u32, a);
}

test "import fixunssfsi" {
    _ = @import("fixunssfsi_test.zig");
}
