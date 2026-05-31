export fn entry() void {
    const x: i32 = @intFromFloat(@as(i32, 54));
    _ = x;
}

// error
//
// :2:34: error: expected float type, found 'i32'
