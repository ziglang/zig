export fn entry() void {
    const x = @intFromFloat(i8, 200);
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :2:33: error: float value '200' cannot be stored in integer type 'i8'
