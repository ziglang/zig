const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");
const linkage = if (builtin.is_test) builtin.GlobalLinkage.Internal else builtin.GlobalLinkage.LinkOnce;

export fn __fixunstfdi(a: f128) -> u64 {
    @setDebugSafety(this, builtin.is_test);
    @setGlobalLinkage(__fixunstfdi, linkage);
    return fixuint(f128, u64, a);
}

test "import fixunstfdi" {
    _ = @import("fixunstfdi_test.zig");
}
