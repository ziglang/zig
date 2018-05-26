const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");

pub extern fn __fixunsdfdi(a: f64) u64 {
    @setRuntimeSafety(builtin.is_test);
    return fixuint(f64, u64, a);
}

test "import fixunsdfdi" {
    _ = @import("fixunsdfdi_test.zig");
}
