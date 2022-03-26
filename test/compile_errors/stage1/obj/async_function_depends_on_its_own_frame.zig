export fn entry() void {
    _ = async amain();
}
fn amain() callconv(.Async) void {
    var x: [@sizeOf(@Frame(amain))]u8 = undefined;
    _ = x;
}

// async function depends on its own frame
//
// tmp.zig:4:1: error: cannot resolve '@Frame(amain)': function not fully analyzed yet
