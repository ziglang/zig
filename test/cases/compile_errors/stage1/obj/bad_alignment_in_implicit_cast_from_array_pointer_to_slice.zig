export fn a() void {
    var x: [10]u8 = undefined;
    var y: []align(16) u8 = &x;
    _ = y;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:30: error: expected type '[]align(16) u8', found '*[10]u8'
