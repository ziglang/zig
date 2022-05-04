export fn entry() void {
    const x = @intToFloat(f32, 1.1);
    _ = x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:32: error: expected int type, found 'comptime_float'
