export fn entry() void {
    _ = async amain();
}
fn amain() callconv(.Async) void {
    return error.ShouldBeCompileError;
}

// returning error from void async function
//
// tmp.zig:5:17: error: expected type 'void', found 'error{ShouldBeCompileError}'
