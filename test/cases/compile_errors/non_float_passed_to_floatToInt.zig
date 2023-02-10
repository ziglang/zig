export fn entry() void {
    const x = @floatToInt(i32, @as(i32, 54));
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :2:32: error: expected float type, found 'i32'
