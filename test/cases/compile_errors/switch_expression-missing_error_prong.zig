const Error = error {
    One,
    Two,
    Three,
    Four,
};
fn f(n: Error!i32) i32 {
    if (n) |x| x else |e| switch (e) {
        error.One => 1,
        error.Two => 2,
        error.Three => 3,
    }
}
fn h(n: Error!i32) i32 {
    n catch |e| switch (e) {
        error.One => 1,
        error.Two => 2,
        error.Three => 3,
    };
}

export fn entry() usize {
    return @sizeOf(@TypeOf(&f)) + @sizeOf(@TypeOf(&h));
}

// error
// backend=stage2
// target=native
//
// :8:27: error: switch must handle all possibilities
// :8:27: note: unhandled error value: 'error.Four'
// :15:17: error: switch must handle all possibilities
// :15:17: note: unhandled error value: 'error.Four'
