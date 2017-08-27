const fixuint = @import("fixuint.zig").fixuint;

export fn __fixunsdfdi(a: f64) -> u64 {
    @setGlobalLinkage(__fixunsdfdi, @import("builtin").GlobalLinkage.LinkOnce);
    return fixuint(f64, u64, a);
}

test "import fixunsdfdi" {
    _ = @import("fixunsdfdi_test.zig");
}

