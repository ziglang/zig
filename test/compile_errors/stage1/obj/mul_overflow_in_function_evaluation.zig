const y = mul(300, 6000);
fn mul(a: u16, b: u16) u16 {
    return a * b;
}

export fn entry() usize { return @sizeOf(@TypeOf(y)); }

// mul overflow in function evaluation
//
// tmp.zig:3:14: error: operation caused overflow
