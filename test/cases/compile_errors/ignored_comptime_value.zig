export fn a() void {
    comptime 1;
}
export fn b() void {
    comptime bar();
}
fn bar() u8 {
    return 2;
}

// error
// backend=stage2
// target=native
//
// :2:5: error: value of type 'comptime_int' ignored
// :2:5: note: all non-void values must be used
// :2:5: note: to discard the value, assign it to '_'
// :5:5: error: value of type 'u8' ignored
// :5:5: note: all non-void values must be used
// :5:5: note: to discard the value, assign it to '_'
