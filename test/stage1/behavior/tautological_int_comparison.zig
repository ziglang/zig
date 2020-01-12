const expect = @import("std").testing.expect;

// https://github.com/ziglang/zig/issues/2146
test "tautological integral comparisons" {
    var u: u4 = undefined;
    var i: i4 = undefined;

    if (u > 15) @compileLog("analyzed impossible branch");
    if (u >= 16) @compileLog("analyzed impossible branch");
    if (u < 16) {} else @compileLog("analyzed impossible branch");
    if (u <= 15) {} else @compileLog("analyzed impossible branch");

    if (15 < u) @compileLog("analyzed impossible branch");
    if (16 <= u) @compileLog("analyzed impossible branch");
    if (16 > u) {} else @compileLog("analyzed impossible branch");
    if (15 >= u) {} else @compileLog("analyzed impossible branch");

    if (i < -8) @compileLog("analyzed impossible branch");
    if (i <= -9) @compileLog("analyzed impossible branch");
    if (i >= -8) {} else @compileLog("analyzed impossible branch");
    if (i > -9) {} else @compileLog("analyzed impossible branch");

    if (-8 > i) @compileLog("analyzed impossible branch");
    if (-9 >= i) @compileLog("analyzed impossible branch");
    if (-8 <= i) {} else @compileLog("analyzed impossible branch");
    if (-9 < i) {} else @compileLog("analyzed impossible branch");

    if (u < comptime largeConstant()) {} else @compileLog("analyzed impossible branch");
    if (u >= comptime largeConstant()) @compileLog("analyzed impossible branch");
    if (i <= comptime signedConstant()) @compileLog("analyzed impossible branch");
    if (i > comptime signedConstant()) {} else @compileLog("analyzed impossible branch");

    const large_constant: u32 = 16;
    const signed_constant: i32 = -9;
    if (u < large_constant) {} else @compileLog("analyzed impossible branch");
    if (u >= large_constant) @compileLog("analyzed impossible branch");
    if (i <= signed_constant) @compileLog("analyzed impossible branch");
    if (i > signed_constant) {} else @compileLog("analyzed impossible branch");
}

fn largeConstant() u32 {
    return 16;
}

fn signedConstant() i32 {
    return -9;
}
