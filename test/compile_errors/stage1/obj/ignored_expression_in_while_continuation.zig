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

// ignored expression in while continuation
//
// tmp.zig:2:24: error: error is ignored. consider using `try`, `catch`, or `if`
// tmp.zig:6:25: error: error is ignored. consider using `try`, `catch`, or `if`
// tmp.zig:10:25: error: error is ignored. consider using `try`, `catch`, or `if`
