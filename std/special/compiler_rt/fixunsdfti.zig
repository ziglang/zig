const fixuint = @import("fixuint.zig").fixuint;

export fn __fixunsdfti(a: f64) -> u128 {
    return fixuint(f64, u128, a);
}

test "import fixunsdfti" {
    _ = @import("fixunsdfti_test.zig");
}
