export fn foo() void {
    while (bar()) |x| {
        _ = x;
    } else |err| {
        _ = err;
    }
}
fn bar() bool {
    return true;
}

// error
//
// :2:15: error: expected error union type, found 'bool'
