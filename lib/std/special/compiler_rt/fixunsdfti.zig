const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");

pub fn __fixunsdfti(a: f64) callconv(.C) u128 {
    @setRuntimeSafety(builtin.is_test);
    return fixuint(f64, u128, a);
}

test {
    _ = @import("fixunsdfti_test.zig");
}
