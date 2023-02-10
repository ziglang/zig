export fn entry() void {
    const x = [_]u8{ .y = 2 };
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :2:15: error: initializing array with struct syntax
