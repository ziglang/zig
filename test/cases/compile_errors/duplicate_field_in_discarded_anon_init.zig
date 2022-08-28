pub export fn entry() void {
    _ = .{ .a = 0, .a = 1 };
}

// error
// backend=stage2
// target=native
//
// :2:21: error: duplicate field
// :2:13: note: other field here
