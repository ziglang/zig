export fn a() void {
    var x: [10]u8 = undefined;
    const y: []align(16) u8 = &x;
    _ = y;
}

// error
//
// :3:31: error: expected type '[]align(16) u8', found '*[10]u8'
// :3:31: note: pointer alignment '1' cannot cast into pointer alignment '16'
