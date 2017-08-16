const fixuint = @import("fixuint.zig").fixuint;

export fn __fixunssfdi(a: f32) -> u64 {
    return fixuint(f32, u64, a);
}

test "import fixunssfdi" {
    _ = @import("fixunssfdi_test.zig");
}
