const y = add(65530, 10);
fn add(a: u16, b: u16) u16 {
    return a + b;
}

export fn entry() usize {
    return @sizeOf(@TypeOf(y));
}

// error
//
// :3:14: error: overflow of integer type 'u16' with value '65540'
// :1:14: note: called at comptime here
