export fn entry() void {
    _ = foo();
}
fn foo() !void {
    return error.OutOfMemory;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:12: error: error is discarded. consider using `try`, `catch`, or `if`
