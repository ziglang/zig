export fn a() void {
    const x: u32 = @intFromFloat(@as(f32, undefined));
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :2:34: error: undefined float value cannot be stored in integer type 'u32'
