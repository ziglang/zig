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
// backend=stage2
// target=native
//
// :3:5: error: cannot assign to constant
// :7:7: error: cannot assign to constant
// :11:7: error: cannot assign to constant
// :15:7: error: cannot assign to constant
// :19:7: error: cannot assign to constant
// :23:7: error: cannot assign to constant
// :27:7: error: cannot assign to constant
// :31:7: error: cannot assign to constant
// :35:7: error: cannot assign to constant
// :39:7: error: cannot assign to constant
// :43:7: error: cannot assign to constant
// :47:7: error: cannot assign to constant
// :51:7: error: cannot assign to constant
// :55:7: error: cannot assign to constant
// :59:7: error: cannot assign to constant
// :63:7: error: cannot assign to constant
// :67:7: error: cannot assign to constant
// :71:7: error: cannot assign to constant
