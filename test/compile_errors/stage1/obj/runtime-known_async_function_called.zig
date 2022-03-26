export fn entry() void {
    _ = async amain();
}
fn amain() void {
    var ptr = afunc;
    _ = ptr();
}
fn afunc() callconv(.Async) void {}

// runtime-known async function called
//
// tmp.zig:6:12: error: function is not comptime-known; @asyncCall required
