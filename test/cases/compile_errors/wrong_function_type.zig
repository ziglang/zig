const fns = [_]fn () void{ a, b, c };
fn a() i32 {
    return 0;
}
fn b() i32 {
    return 1;
}
fn c() i32 {
    return 2;
}
export fn entry() usize {
    return @sizeOf(@TypeOf(fns));
}

// error
// backend=stage2
// target=native
//
// :1:28: error: expected type 'fn () void', found 'fn () i32'
// :1:28: note: return type 'i32' cannot cast into return type 'void'
