export fn foo() void {
    bar();
}
fn bar() i32 {
    return 0;
}

// error
//
// :2:8: error: value of type 'i32' ignored
// :2:8: note: all non-void values must be used
// :2:8: note: to discard the value, assign it to '_'
