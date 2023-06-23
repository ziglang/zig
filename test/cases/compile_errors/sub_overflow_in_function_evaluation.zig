const y = sub(10, 20);
fn sub(a: u16, b: u16) u16 {
    return a - b;
}

export fn entry() usize {
    return @sizeOf(@TypeOf(&y));
}

// error
// backend=stage2
// target=native
//
// :3:14: error: overflow of integer type 'u16' with value '-10'
// :1:14: note: called from here
