const fixuint = @import("fixuint.zig").fixuint;

export fn __fixunssfti(a: f32) -> u128 {
    @setGlobalLinkage(__fixunssfti, @import("builtin").GlobalLinkage.LinkOnce);
    return fixuint(f32, u128, a);
}

test "import fixunssfti" {
    _ = @import("fixunssfti_test.zig");
}

