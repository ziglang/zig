const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");

pub extern fn __fixunsdfti(a: f64) u128 {
    @setRuntimeSafety(builtin.is_test);
    return fixuint(f64, u128, a);
}

test "import fixunsdfti" {
    _ = @import("fixunsdfti_test.zig");
}
