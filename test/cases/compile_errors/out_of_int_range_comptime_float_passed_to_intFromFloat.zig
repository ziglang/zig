export fn entry() void {
    const x: i8 = @intFromFloat(200);
    _ = x;
}

// error
//
// :2:33: error: float value '200' cannot be stored in integer type 'i8'
