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
//
// :5:16: error: unable to resolve comptime value
// :5:16: note: argument to comptime parameter must be comptime-known
// :1:8: note: parameter declared comptime here
