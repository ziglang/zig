const fixint = @import("fixint.zig").fixint;
const builtin = @import("builtin");

pub extern fn __fixtfdi(a: f128) i64 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f128, i64, a);
}

test "import fixtfdi" {
    _ = @import("fixtfdi_test.zig");
}
