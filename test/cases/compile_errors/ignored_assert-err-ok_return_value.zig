export fn foo() void {
    bar() catch unreachable;
}
fn bar() anyerror!i32 {
    return 0;
}

// error
// backend=stage2
// target=native
//
// :2:11: error: value of type 'i32' ignored
// :2:11: note: all non-void values must be used
// :2:11: note: this error can be suppressed by assigning the value to '_'
