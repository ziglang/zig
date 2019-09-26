const fixint = @import("fixint.zig").fixint;
const builtin = @import("builtin");

pub extern fn __fixtfsi(a: f128) i32 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f128, i32, a);
}

test "import fixtfsi" {
    _ = @import("fixtfsi_test.zig");
}
