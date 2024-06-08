export fn foo() void {
    defer bar();
}
fn bar() anyerror!i32 {
    return 0;
}

export fn foo2() void {
    defer bar2();
}
fn bar2() anyerror {
    return error.a;
}

// error
// backend=stage2
// target=native
//
// :2:14: error: error union is ignored
// :2:14: note: consider using 'try', 'catch', or 'if'
// :9:15: error: error set is ignored
