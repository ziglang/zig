export fn entry(base: f32, exponent: f32) f32 {
    return base ** exponent;
}

// error
// backend=stage2
// target=native
//
// :2:12: error: expected indexable; found 'f32'
// :2:17: note: this operator multiplies arrays; use std.math.pow for exponentiation
