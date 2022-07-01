const y = neg(-128);
fn neg(x: i8) i8 {
    return -x;
}

export fn entry() usize { return @sizeOf(@TypeOf(y)); }

// error
// backend=stage1
// target=native
//
// tmp.zig:3:12: error: negation caused overflow
