const fixint = @import("fixint.zig").fixint;
const builtin = @import("builtin");

pub fn __fixsfti(a: f32) callconv(.C) i128 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f32, i128, a);
}

test {
    _ = @import("fixsfti_test.zig");
}
