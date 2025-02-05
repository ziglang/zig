fn returns() usize {
    return 2;
}
export fn f1() void {
    while (true) returns();
}
export fn f2() void {
    var x: ?i32 = null;
    _ = &x;
    while (x) |_| returns();
}
export fn f3() void {
    var x: anyerror!i32 = error.Bad;
    _ = &x;
    while (x) |_| returns() else |_| unreachable;
}
export fn f4() void {
    var a = true;
    _ = &a;
    while (a) {} else true;
}
export fn f5() void {
    var a = true;
    _ = &a;
    const foo = while (a) returns() else true;
    _ = foo;
}

// error
// backend=stage2
// target=native
//
// :5:25: error: value of type 'usize' ignored
// :5:25: note: all non-void values must be used
// :5:25: note: to discard the value, assign it to '_'
// :10:26: error: value of type 'usize' ignored
// :10:26: note: all non-void values must be used
// :10:26: note: to discard the value, assign it to '_'
// :15:26: error: value of type 'usize' ignored
// :15:26: note: all non-void values must be used
// :15:26: note: to discard the value, assign it to '_'
// :20:23: error: value of type 'bool' ignored
// :20:23: note: all non-void values must be used
// :20:23: note: to discard the value, assign it to '_'
// :25:34: error: value of type 'usize' ignored
// :25:34: note: all non-void values must be used
// :25:34: note: to discard the value, assign it to '_'
