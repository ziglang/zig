export fn foo() void {
    while (bar()) {}
}
fn bar() anyerror!i32 {
    return 1;
}

// error
//
// :2:15: error: expected type 'bool', found 'anyerror!i32'
