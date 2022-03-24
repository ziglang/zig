export fn entry(x: f32) u32 {
    return @popCount(f32, x);
}

// @popCount - non-integer
//
// tmp.zig:2:22: error: expected integer type, found 'f32'
