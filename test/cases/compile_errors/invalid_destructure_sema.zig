export fn foo() void {
    const x, const y = 123;
    _ = .{ x, y };
}

export fn bar() void {
    var x: u32 = undefined;
    x, const y: u64 = blk: {
        if (false) break :blk .{ 1, 2 };
        const val = .{ 3, 4, 5 };
        break :blk val;
    };
    _ = y;
}

// error
// backend=stage2
// target=native
//
// :2:24: error: type 'comptime_int' cannot be destructured
// :2:22: note: result destructured here
// :11:20: error: expected 2 elements for destructure, found 3
// :8:21: note: result destructured here
