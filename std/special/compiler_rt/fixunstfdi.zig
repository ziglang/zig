const fixuint = @import("fixuint.zig").fixuint;

export fn __fixunstfdi(a: f128) -> u64 {
    @setGlobalLinkage(__fixunstfdi, @import("builtin").GlobalLinkage.LinkOnce);
    return fixuint(f128, u64, a);
}

test "import fixunstfdi" {
    _ = @import("fixunstfdi_test.zig");
}
