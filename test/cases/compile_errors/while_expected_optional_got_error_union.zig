export fn foo() void {
    while (bar()) |x| {
        _ = x;
    }
}
fn bar() anyerror!i32 {
    return 1;
}

// error
// backend=stage2
// target=native
//
// :2:15: error: expected optional type, found 'anyerror!i32'
