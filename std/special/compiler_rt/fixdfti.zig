const fixint = @import("fixint.zig").fixint;
const builtin = @import("builtin");

pub extern fn __fixdfti(a: f64) i128 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f64, i128, a);
}

test "import fixdfti" {
    _ = @import("fixdfti_test.zig");
}
