export fn entry() void {
    _ = foo();
}
fn foo() !void {
    return error.OutOfMemory;
}

// discarding error value
//
// tmp.zig:2:12: error: error is discarded. consider using `try`, `catch`, or `if`
