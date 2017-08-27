const udivmod = @import("udivmod.zig").udivmod;
const builtin = @import("builtin");

export fn __udivmodti4(a: u128, b: u128, maybe_rem: ?&u128) -> u128 {
    @setDebugSafety(this, builtin.is_test);
    @setGlobalLinkage(__udivmodti4, builtin.GlobalLinkage.LinkOnce);
    return udivmod(u128, a, b, maybe_rem);
}

test "import udivmodti4" {
    _ = @import("udivmodti4_test.zig");
}
