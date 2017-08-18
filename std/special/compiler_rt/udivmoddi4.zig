const udivmod = @import("udivmod.zig").udivmod;

export fn __udivmoddi4(a: u64, b: u64, maybe_rem: ?&u64) -> u64 {
    return udivmod(u64, a, b, maybe_rem);
}

test "import udivmoddi4" {
    _ = @import("udivmoddi4_test.zig");
}
