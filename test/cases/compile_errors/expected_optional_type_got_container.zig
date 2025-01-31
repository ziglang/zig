export fn foo() void {
    while (bar()) |x| {
        _ = x;
    }
}
const X = enum { a };
fn bar() X {
    return .a;
}

// error
// backend=stage2
// target=native
//
// :2:15: error: expected optional type, found 'tmp.X'
// :6:11: note: enum declared here
