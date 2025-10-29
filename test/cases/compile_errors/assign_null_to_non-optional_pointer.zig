const a: *u8 = null;

export fn entry() usize {
    return @sizeOf(@TypeOf(a));
}

// error
//
// :1:16: error: expected type '*u8', found '@TypeOf(null)'
