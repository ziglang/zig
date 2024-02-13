fn returns() usize {
    return 2;
}
export fn f1() void {
    for ("hello") |_| returns();
}
export fn f2() void {
    var x: anyerror!i32 = error.Bad;
    for ("hello") |_| returns() else unreachable;
    _ = &x;
}
export fn f3() void {
    for ("hello") |_| {} else true;
}
export fn f4() void {
    const foo = for ("hello") |_| returns() else true;
    _ = foo;
}

// error
// backend=stage2
// target=native
//
// :5:30: error: value of type 'usize' ignored
// :5:30: note: all non-void values must be used
// :5:30: note: this error can be suppressed by assigning the value to '_'
// :9:30: error: value of type 'usize' ignored
// :9:30: note: all non-void values must be used
// :9:30: note: this error can be suppressed by assigning the value to '_'
// :13:31: error: value of type 'bool' ignored
// :13:31: note: all non-void values must be used
// :13:31: note: this error can be suppressed by assigning the value to '_'
// :16:42: error: value of type 'usize' ignored
// :16:42: note: all non-void values must be used
// :16:42: note: this error can be suppressed by assigning the value to '_'
