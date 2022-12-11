export fn entry() void {
    _ = async amain();
}
fn amain() callconv(.Async) void {
    return error.ShouldBeCompileError;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:5:17: error: expected type 'void', found 'error{ShouldBeCompileError}'
