const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");
const linkage = @import("index.zig").linkage;

export fn __fixunssfti(a: f32) -> u128 {
    @setDebugSafety(this, builtin.is_test);
    @setGlobalLinkage(__fixunssfti, linkage);
    return fixuint(f32, u128, a);
}

test "import fixunssfti" {
    _ = @import("fixunssfti_test.zig");
}

