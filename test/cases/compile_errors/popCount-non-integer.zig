export fn entry(x: f32) u32 {
    return @popCount(x);
}

// error
// backend=stage2
// target=native
//
// :2:22: error: expected integer or vector, found 'f32'
