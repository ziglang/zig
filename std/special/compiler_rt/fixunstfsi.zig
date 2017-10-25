const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");
const linkage = @import("index.zig").linkage;

export fn __fixunstfsi(a: f128) -> u32 {
    @setDebugSafety(this, builtin.is_test);
    @setGlobalLinkage(__fixunstfsi, linkage);
    return fixuint(f128, u32, a);
}

test "import fixunstfsi" {
    _ = @import("fixunstfsi_test.zig");
}
