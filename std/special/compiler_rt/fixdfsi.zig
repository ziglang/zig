const fixint = @import("fixint.zig").fixint;
const builtin = @import("builtin");

pub extern fn __fixdfsi(a: f64) i32 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f64, i32, a);
}

test "import fixdfsi" {
    _ = @import("fixdfsi_test.zig");
}
