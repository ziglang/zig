export fn foo() void {
    defer bar();
}
fn bar() anyerror!i32 {
    return 0;
}

// error
// backend=stage2
// target=native
//
// :2:14: error: error is ignored
// :2:14: note: consider using 'try', 'catch', or 'if'
