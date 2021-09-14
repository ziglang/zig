const fixint = @import("fixint.zig").fixint;
const builtin = @import("builtin");

pub fn __fixtfdi(a: f128) callconv(.C) i64 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f128, i64, a);
}

test {
    _ = @import("fixtfdi_test.zig");
}
