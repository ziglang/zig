export fn entry(x: u8, y: u8) u8 {
    return x << y;
}

// shifting RHS is log2 of LHS int bit width
//
// tmp.zig:2:17: error: expected type 'u3', found 'u8'
