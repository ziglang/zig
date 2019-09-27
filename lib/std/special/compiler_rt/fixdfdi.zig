const fixint = @import("fixint.zig").fixint;
const builtin = @import("builtin");

pub extern fn __fixdfdi(a: f64) i64 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f64, i64, a);
}

test "import fixdfdi" {
    _ = @import("fixdfdi_test.zig");
}
