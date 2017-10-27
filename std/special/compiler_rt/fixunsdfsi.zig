const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");
const linkage = @import("index.zig").linkage;

export fn __fixunsdfsi(a: f64) -> u32 {
    @setDebugSafety(this, builtin.is_test);
    @setGlobalLinkage(__fixunsdfsi, linkage);
    return fixuint(f64, u32, a);
}

test "import fixunsdfsi" {
    _ = @import("fixunsdfsi_test.zig");
}

