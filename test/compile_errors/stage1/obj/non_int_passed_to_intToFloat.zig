export fn entry() void {
    const x = @intToFloat(f32, 1.1);
    _ = x;
}

// non int passed to @intToFloat
//
// tmp.zig:2:32: error: expected int type, found 'comptime_float'
