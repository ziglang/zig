export fn a() void {
    var x: anyframe = undefined;
    var y: anyframe->i32 = x;
    _ = .{ &x, &y };
}
export fn b() void {
    var x: i32 = undefined;
    var y: anyframe->i32 = x;
    _ = .{ &x, &y };
}
export fn c() void {
    var x: @Frame(func) = undefined;
    var y: anyframe->i32 = &x;
    _ = .{ &x, &y };
}
fn func() void {}

// error
// backend=stage1
// target=native
//
// :3:28: error: expected type 'anyframe->i32', found 'anyframe'
// :8:28: error: expected type 'anyframe->i32', found 'i32'
// tmp.zig:13:29: error: expected type 'anyframe->i32', found '*@Frame(func)'
