const fixuint = @import("fixuint.zig").fixuint;

export fn __fixunstfti(a: f128) -> u128 {
    return fixuint(f128, u128, a);
}

test "fixunstfti" {
    _ = @import("fixunstfti_test.zig");
}

