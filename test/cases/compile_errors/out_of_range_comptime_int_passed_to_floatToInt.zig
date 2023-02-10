export fn entry() void {
    const x = @floatToInt(i8, 200);
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :2:31: error: float value '200' cannot be stored in integer type 'i8'
