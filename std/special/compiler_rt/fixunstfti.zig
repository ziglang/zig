const fixuint = @import("fixuint.zig").fixuint;

export fn __fixunstfti(a: f128) -> u128 {
    @setGlobalLinkage(__fixunstfti, @import("builtin").GlobalLinkage.LinkOnce);
    return fixuint(f128, u128, a);
}

test "import fixunstfti" {
    _ = @import("fixunstfti_test.zig");
}

