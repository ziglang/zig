export fn entry() void {
    _ = async amain();
}
fn amain() callconv(.Async) void {
    other();
}
fn other() void {
    var x: [@sizeOf(@Frame(amain))]u8 = undefined;
    _ = &x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:1: error: unable to determine async function frame of 'amain'
// tmp.zig:5:10: note: analysis of function 'other' depends on the frame
