const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");

pub extern fn __fixunsdfsi(a: f64) u32 {
    @setRuntimeSafety(builtin.is_test);
    return fixuint(f64, u32, a);
}

test "import fixunsdfsi" {
    _ = @import("fixunsdfsi_test.zig");
}
