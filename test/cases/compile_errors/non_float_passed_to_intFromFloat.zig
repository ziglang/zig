export fn entry() void {
    const x: i32 = @intFromFloat(@as(i32, 54));
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :2:34: error: expected float type, found 'i32'
