export fn entry() void {
    const x = @intToFloat(f32, 1.1);
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :2:32: error: expected integer type, found 'comptime_float'
