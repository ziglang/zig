const udivmod = @import("udivmod.zig").udivmod;
const builtin = @import("builtin");
const linkage = if (builtin.is_test) builtin.GlobalLinkage.Internal else builtin.GlobalLinkage.LinkOnce;

export fn __udivmoddi4(a: u64, b: u64, maybe_rem: ?&u64) -> u64 {
    @setDebugSafety(this, builtin.is_test);
    @setGlobalLinkage(__udivmoddi4, linkage);
    return udivmod(u64, a, b, maybe_rem);
}

test "import udivmoddi4" {
    _ = @import("udivmoddi4_test.zig");
}
