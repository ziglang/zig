export fn entry() void {
    _ = async amain();
}
fn amain() void {
    var ptr = afunc;
    _ = ptr();
    _ = &ptr;
}
fn afunc() callconv(.Async) void {}

// error
// backend=stage1
// target=native
//
// tmp.zig:6:12: error: function is not comptime-known; @asyncCall required
