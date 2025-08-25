export fn foo() void {
    while (bar()) {}
}
fn bar() anyerror!i32 {
    return 1;
}

// error
// backend=stage2
// target=native
//
// :2:15: error: expected type 'bool', found 'anyerror!i32'
