const y = mul(300, 6000);
fn mul(a: u16, b: u16) u16 {
    return a * b;
}

export fn entry() usize {
    return @sizeOf(@TypeOf(&y));
}

// error
//
// :3:14: error: overflow of integer type 'u16' with value '1800000'
// :1:14: note: called at comptime here
