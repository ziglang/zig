export fn a() void {
    while (true) : (bad()) {}
}
export fn b() void {
    var x: anyerror!i32 = 1234;
    while (x) |_| : (bad()) {} else |_| {}
}
export fn c() void {
    var x: ?i32 = 1234;
    while (x) |_| : (bad()) {}
}
fn bad() anyerror!void {
    return error.Bad;
}

// error
// backend=stage2
// target=native
//
// :2:24: error: error is ignored
// :2:24: note: consider using `try`, `catch`, or `if`
// :6:25: error: error is ignored
// :6:25: note: consider using `try`, `catch`, or `if`
// :10:25: error: error is ignored
// :10:25: note: consider using `try`, `catch`, or `if`
