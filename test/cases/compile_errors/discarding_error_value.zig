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
// :2:12: error: error is discarded
// :2:12: note: consider using 'try', 'catch', or 'if'
