export fn entry() void {
    const x: f64 = 16777217;
    const y: f32 = x;
    _ = y;
}

// error
// backend=stage2
// target=native
//
// :3:20: error: type 'f32' cannot represent float value '16777217'
