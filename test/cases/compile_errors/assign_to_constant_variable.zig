export fn entry1() void {
    const a = 1;
    a = 1;
}
export fn entry2() void {
    const a = 1;
    a |= 1;
}
export fn entry3() void {
    const a = 1;
    a %= 1;
}
export fn entry4() void {
    const a = 1;
    a ^= 1;
}
export fn entry5() void {
    const a = 1;
    a += 1;
}
export fn entry6() void {
    const a = 1;
    a +%= 1;
}
export fn entry7() void {
    const a = 1;
    a +|= 1;
}
export fn entry8() void {
    const a = 1;
    a -= 1;
}
export fn entry9() void {
    const a = 1;
    a -%= 1;
}
export fn entry10() void {
    const a = 1;
    a -|= 1;
}
export fn entry11() void {
    const a = 1;
    a *= 1;
}
export fn entry12() void {
    const a = 1;
    a *%= 1;
}
export fn entry13() void {
    const a = 1;
    a *|= 1;
}
export fn entry14() void {
    const a = 1;
    a /= 1;
}
export fn entry15() void {
    const a = 1;
    a &= 1;
}
export fn entry16() void {
    const a = 1;
    a <<= 1;
}
export fn entry17() void {
    const a = 1;
    a <<|= 1;
}
export fn entry18() void {
    const a = 1;
    a >>= 1;
}

// error
//
// :3:5: error: cannot assign to constant
// :7:5: error: cannot assign to constant
// :11:5: error: cannot assign to constant
// :15:5: error: cannot assign to constant
// :19:5: error: cannot assign to constant
// :23:5: error: cannot assign to constant
// :27:5: error: cannot assign to constant
// :31:5: error: cannot assign to constant
// :35:5: error: cannot assign to constant
// :39:5: error: cannot assign to constant
// :43:5: error: cannot assign to constant
// :47:5: error: cannot assign to constant
// :51:5: error: cannot assign to constant
// :55:5: error: cannot assign to constant
// :59:5: error: cannot assign to constant
// :63:5: error: cannot assign to constant
// :67:5: error: cannot assign to constant
// :71:5: error: cannot assign to constant
