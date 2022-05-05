export fn entry() void {
    func();
}
fn func() void {
    _ = @frame();
}

// error
// backend=stage1
// target=native
//
// tmp.zig:1:1: error: function with calling convention 'C' cannot be async
// tmp.zig:5:9: note: @frame() causes function to be async
