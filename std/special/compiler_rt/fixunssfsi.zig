const fixuint = @import("fixuint.zig").fixuint;

export fn __fixunssfsi(a: f32) -> u32 {
    @setGlobalLinkage(__fixunssfsi, @import("builtin").GlobalLinkage.LinkOnce);
    return fixuint(f32, u32, a);
}

test "import fixunssfsi" {
    _ = @import("fixunssfsi_test.zig");
}
