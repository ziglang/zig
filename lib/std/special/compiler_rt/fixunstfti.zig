const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");

pub fn __fixunstfti(a: f128) callconv(.C) u128 {
    @setRuntimeSafety(builtin.is_test);
    return fixuint(f128, u128, a);
}

test {
    _ = @import("fixunstfti_test.zig");
}
