export fn a() void {
    var x: [10]u8 = undefined;
    var y: []align(16) u8 = &x;
    _ = y;
}

// error
// backend=stage2
// target=native
//
// :3:29: error: expected type '[]align(16) u8', found '*[10]u8'
// :3:29: note: pointer alignment '1' cannot cast into pointer alignment '16'
