export fn entry(x: f32) u32 {
    return @popCount(f32, x);
}

// error
// backend=stage2
// target=native
//
// :2:27: error: expected integer or vector, found 'f32'
