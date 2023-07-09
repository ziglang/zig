export fn foo() void {
    while (bar()) |x| {
        _ = x;
    }
}
fn bar() bool {
    return true;
}

// error
// backend=stage2
// target=native
//
// :2:15: error: expected optional type, found 'bool'
