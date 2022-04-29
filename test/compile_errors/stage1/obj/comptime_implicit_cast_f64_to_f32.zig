export fn entry() void {
    const x: f64 = 16777217;
    const y: f32 = x;
    _ = y;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:20: error: cast of value 16777217.000000 to type 'f32' loses information
