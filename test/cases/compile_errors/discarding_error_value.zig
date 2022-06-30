export fn entry() void {
    _ = foo();
}
fn foo() !void {
    return error.OutOfMemory;
}

// error
// backend=stage2
// target=native
//
// :2:12: error: error is discarded. consider using `try`, `catch`, or `if`
