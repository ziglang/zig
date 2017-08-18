const __udivmodti4 = @import("udivmodti4.zig").__udivmodti4;

export fn __umodti3(a: u128, b: u128) -> u128 {
    var r: u128 = undefined;
    _ = __udivmodti4(a, b, &r);
    return r;
}
