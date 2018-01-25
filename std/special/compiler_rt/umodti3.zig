const __udivmodti4 = @import("udivmodti4.zig").__udivmodti4;
const builtin = @import("builtin");

pub extern fn __umodti3(a: u128, b: u128) -> u128 {
    @setRuntimeSafety(builtin.is_test);
    var r: u128 = undefined;
    _ = __udivmodti4(a, b, &r);
    return r;
}
