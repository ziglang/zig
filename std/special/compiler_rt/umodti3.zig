const __udivmodti4 = @import("udivmodti4.zig").__udivmodti4;
const builtin = @import("builtin");

export fn __umodti3(a: u128, b: u128) -> u128 {
    @setDebugSafety(this, builtin.is_test);
    @setGlobalLinkage(__umodti3, builtin.GlobalLinkage.LinkOnce);
    var r: u128 = undefined;
    _ = __udivmodti4(a, b, &r);
    return r;
}
