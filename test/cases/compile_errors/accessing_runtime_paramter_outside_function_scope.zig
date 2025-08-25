export fn entry(y: u8) void {
    const Thing = struct {
        y: u8 = y,
    };
    _ = Thing{ .y = 1 };
}

// error
// backend=stage2
// target=native
//
// :3:17: error: 'y' not accessible outside function scope
