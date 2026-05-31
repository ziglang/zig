const x: u8 = 300;
export fn entry() usize {
    return @sizeOf(@TypeOf(x));
}

// error
//
// :1:15: error: type 'u8' cannot represent integer value '300'
