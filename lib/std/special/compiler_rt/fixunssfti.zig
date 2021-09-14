const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");

pub fn __fixunssfti(a: f32) callconv(.C) u128 {
    @setRuntimeSafety(builtin.is_test);
    return fixuint(f32, u128, a);
}

test {
    _ = @import("fixunssfti_test.zig");
}
