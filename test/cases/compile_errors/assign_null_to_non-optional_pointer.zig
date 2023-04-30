const a: *u8 = null;

export fn entry() usize {
    return @sizeOf(@TypeOf(a));
}

// error
// backend=stage2
// target=native
//
// :1:16: error: expected type '*u8', found '@TypeOf(null)'
