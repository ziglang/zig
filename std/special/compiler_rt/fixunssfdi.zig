const fixuint = @import("fixuint.zig").fixuint;

export fn __fixunssfdi(a: f32) -> u64 {
    @setGlobalLinkage(__fixunssfdi, @import("builtin").GlobalLinkage.LinkOnce);
    return fixuint(f32, u64, a);
}

test "import fixunssfdi" {
    _ = @import("fixunssfdi_test.zig");
}
