export fn entry(x: f32) u32 {
    return @popCount(f32, x);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:22: error: expected integer type, found 'f32'
