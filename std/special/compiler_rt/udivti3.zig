const __udivmodti4 = @import("udivmodti4.zig").__udivmodti4;
const builtin = @import("builtin");
const linkage = if (builtin.is_test) builtin.GlobalLinkage.Internal else builtin.GlobalLinkage.LinkOnce;

export fn __udivti3(a: u128, b: u128) -> u128 {
    @setDebugSafety(this, builtin.is_test);
    @setGlobalLinkage(__udivti3, linkage);
    return __udivmodti4(a, b, null);
}
