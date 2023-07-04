const fns = [_](fn (i32) i32){ a, b, c };
pub fn a(x: i32) i32 {
    return x + 0;
}
pub fn b(x: i32) i32 {
    return x + 1;
}
export fn c(x: i32) i32 {
    return x + 2;
}

export fn entry() usize {
    return @sizeOf(@TypeOf(fns));
}

// error
// backend=stage2
// target=native
//
// :1:38: error: expected type 'fn (i32) i32', found 'fn (i32) callconv(.C) i32'
// :1:38: note: calling convention 'C' cannot cast into calling convention 'Unspecified'
