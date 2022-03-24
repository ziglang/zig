const y = add(65530, 10);
fn add(a: u16, b: u16) u16 {
    return a + b;
}

export fn entry() usize { return @sizeOf(@TypeOf(y)); }

// add overflow in function evaluation
//
// tmp.zig:3:14: error: operation caused overflow
