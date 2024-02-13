var s_buffer: [10]u8 = undefined;
pub fn pass(in: []u8) []u8 {
    var out = &s_buffer;
    _ = &out;
    out.*.* = in[0];
    return out.*[0..1];
}

export fn entry() usize {
    return @sizeOf(@TypeOf(&pass));
}

// error
// backend=stage2
// target=native
//
// :5:10: error: cannot dereference non-pointer type '[10]u8'
