export fn entry() void {
    _ = async amain();
}
fn amain() i32 {
    var frame: @Frame(foo) = undefined;
    return await @asyncCall(&frame, false, foo, .{});
}
fn foo() i32 {
    return 1234;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:6:37: error: expected type '*i32', found 'bool'
