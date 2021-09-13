const fixint = @import("fixint.zig").fixint;
const builtin = @import("builtin");

pub fn __fixtfsi(a: f128) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f128, i32, a);
}

test {
    _ = @import("fixtfsi_test.zig");
}
