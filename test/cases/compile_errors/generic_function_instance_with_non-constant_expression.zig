fn foo(comptime x: i32, y: i32) i32 {
    return x + y;
}
fn test1(a: i32, b: i32) i32 {
    return foo(a, b);
}

export fn entry() usize {
    return @sizeOf(@TypeOf(&test1));
}

// error
// backend=stage2
// target=native
//
// :5:16: error: runtime-known argument passed to comptime parameter
// :1:17: note: declared comptime here
