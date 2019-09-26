const fixint = @import("fixint.zig").fixint;
const builtin = @import("builtin");

pub extern fn __fixtfti(a: f128) i128 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f128, i128, a);
}

test "import fixtfti" {
    _ = @import("fixtfti_test.zig");
}
