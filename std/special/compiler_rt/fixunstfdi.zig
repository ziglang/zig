const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");

pub extern fn __fixunstfdi(a: f128) -> u64 {
    @setDebugSafety(this, builtin.is_test);
    return fixuint(f128, u64, a);
}

test "import fixunstfdi" {
    _ = @import("fixunstfdi_test.zig");
}
