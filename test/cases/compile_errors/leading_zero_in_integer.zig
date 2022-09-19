export fn entry1() void {
    const T = u000123;
    _ = T;
}
export fn entry2() void {
    _ = i0;
    _ = u0;
    var x: i01 = 1;
    _ = x;
}
export fn entry3() void {
    _ = 000123;
}
export fn entry4() void {
    _ = 01;
}

// error
// backend=llvm
// target=native
//
// :2:15: error: primitive integer type 'u000123' has leading zero
// :8:12: error: primitive integer type 'i01' has leading zero
// :12:9: error: number '000123' has leading zero
// :12:9: note: use '0o' prefix for octal literals
// :15:9: error: number '01' has leading zero
// :15:9: note: use '0o' prefix for octal literals
