const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");
const linkage = if (builtin.is_test) builtin.GlobalLinkage.Internal else builtin.GlobalLinkage.LinkOnce;

export fn __fixunstfti(a: f128) -> u128 {
    @setDebugSafety(this, builtin.is_test);
    @setGlobalLinkage(__fixunstfti, linkage);
    return fixuint(f128, u128, a);
}

test "import fixunstfti" {
    _ = @import("fixunstfti_test.zig");
}

