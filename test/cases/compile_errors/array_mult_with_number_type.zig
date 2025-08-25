const exponent: f32 = 1.0;
export fn entry(base: f32) f32 {
    return base ** exponent;
}

// error
//
// :3:12: error: expected indexable; found 'f32'
// :3:17: note: this operator multiplies arrays; use std.math.pow for exponentiation
