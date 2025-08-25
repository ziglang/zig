pub export fn entry() void {
    const x: []u8 = undefined;
    const y: f32 = x;
    _ = y;
}

// error
// backend=stage2
// target=native
//
// :3:20: error: expected type 'f32', found '[]u8'
