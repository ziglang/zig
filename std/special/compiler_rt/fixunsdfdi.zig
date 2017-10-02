const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");
const linkage = if (builtin.is_test) builtin.GlobalLinkage.Internal else builtin.GlobalLinkage.LinkOnce;

export fn __fixunsdfdi(a: f64) -> u64 {
    @setDebugSafety(this, builtin.is_test);
    @setGlobalLinkage(__fixunsdfdi, linkage);
    return fixuint(f64, u64, a);
}

test "import fixunsdfdi" {
    _ = @import("fixunsdfdi_test.zig");
}

