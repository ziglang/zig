fn returns() usize {
    return 2;
}
export fn f1() void {
    while (true) returns();
}
export fn f2() void {
    var x: ?i32 = null;
    while (x) |_| returns();
}
export fn f3() void {
    var x: anyerror!i32 = error.Bad;
    while (x) |_| returns() else |_| unreachable;
}
export fn f4() void {
    var a = true;
    while (a) {} else true;
}
export fn f5() void {
    var a = true;
    const foo = while (a) returns() else true;
    _ = foo;
}

// error
// backend=stage2
// target=native
//
// :5:25: error: value of type 'usize' ignored
// :5:25: note: all non-void values must be used
// :5:25: note: this error can be suppressed by assigning the value to '_'
// :9:26: error: value of type 'usize' ignored
// :9:26: note: all non-void values must be used
// :9:26: note: this error can be suppressed by assigning the value to '_'
// :13:26: error: value of type 'usize' ignored
// :13:26: note: all non-void values must be used
// :13:26: note: this error can be suppressed by assigning the value to '_'
// :17:23: error: value of type 'bool' ignored
// :17:23: note: all non-void values must be used
// :17:23: note: this error can be suppressed by assigning the value to '_'
// :21:34: error: value of type 'usize' ignored
// :21:34: note: all non-void values must be used
// :21:34: note: this error can be suppressed by assigning the value to '_'
