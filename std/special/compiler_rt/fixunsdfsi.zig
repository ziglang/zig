const fixuint = @import("fixuint.zig").fixuint;

export fn __fixunsdfsi(a: f64) -> u32 {
    return fixuint(f64, u32, a);
}

test "import fixunsdfsi" {
    _ = @import("fixunsdfsi_test.zig");
}

