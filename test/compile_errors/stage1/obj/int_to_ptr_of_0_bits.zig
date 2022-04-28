export fn foo() void {
    var x: usize = 0x1000;
    var y: *void = @intToPtr(*void, x);
    _ = y;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:30: error: type '*void' has 0 bits and cannot store information
