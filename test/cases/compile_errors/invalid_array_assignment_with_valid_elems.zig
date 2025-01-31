export fn a() void {
    const x = [_]u16{ 1, 2, 3 };
    const y: [3]i32 = x;
    _ = y;
}

// error
// backend=stage2
// target=native
//
// 3:23: error: expected type '[3]i32', found '[3]u16'
