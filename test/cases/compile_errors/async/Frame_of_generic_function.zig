export fn entry() void {
    var frame: @Frame(func) = undefined;
    _ = &frame;
}
fn func(comptime T: type) void {
    var x: T = undefined;
    _ = &x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:16: error: @Frame() of generic function
