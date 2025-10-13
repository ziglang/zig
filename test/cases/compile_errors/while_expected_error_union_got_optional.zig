export fn foo() void {
    while (bar()) |x| {
        _ = x;
    } else |err| {
        _ = err;
    }
}
fn bar() ?i32 {
    return 1;
}

// error
//
// :2:15: error: expected error union type, found '?i32'
