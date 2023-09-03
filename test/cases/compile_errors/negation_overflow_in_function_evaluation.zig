const y = neg(-128);
fn neg(x: i8) i8 {
    return -x;
}

export fn entry() usize {
    return @sizeOf(@TypeOf(&y));
}

// error
// backend=stage2
// target=native
//
// :3:12: error: overflow of integer type 'i8' with value '128'
// :1:14: note: called from here
