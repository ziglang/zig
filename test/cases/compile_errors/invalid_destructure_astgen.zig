export fn foo() void {
    const x, const y = .{ 1, 2, 3 };
    _ = .{ x, y };
}

export fn bar() void {
    var x: u32 = undefined;
    x, const y: u64 = blk: {
        if (true) break :blk .{ 1, 2 };
        break :blk .{ .x = 123, .y = 456 };
    };
    _ = y;
}

// error
// backend=stage2
// target=native
//
// :2:25: error: expected 2 elements for destructure, found 3
// :2:22: note: result destructured here
// :10:21: error: struct value cannot be destructured
// :8:21: note: result destructured here
