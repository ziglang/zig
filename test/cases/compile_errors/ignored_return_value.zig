export fn foo() void {
    bar();
}
fn bar() i32 {
    return 0;
}

// error
// backend=stage2
// target=native
//
// :2:8: error: value of type 'i32' ignored
// :2:8: note: all non-void values must be used
// :2:8: note: this error can be suppressed by assigning the value to '_'
