const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");

pub fn __fixunstfdi(a: f128) callconv(.C) u64 {
    @setRuntimeSafety(builtin.is_test);
    return fixuint(f128, u64, a);
}

test {
    _ = @import("fixunstfdi_test.zig");
}
