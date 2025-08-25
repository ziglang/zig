fn f(n: Error!i32) i32 {
    if (n) |x|
        _ = x
    else |e| switch (e) {
        error.Foo => 1,
        error.Bar => 2,
        error.Baz => 3,
        error.Foo => 2,
    }
}
fn g(n: Error!i32) i32 {
    n catch |e| switch (e) {
        error.Foo => 1,
        error.Bar => 2,
        error.Baz => 3,
        error.Foo => 2,
    };
}

const Error = error{ Foo, Bar, Baz };

export fn entry() usize {
    return @sizeOf(@TypeOf(&f)) + @sizeOf(@TypeOf(&g));
}

// error
// backend=stage2
// target=native
//
// :8:9: error: duplicate switch value
// :5:9: note: previous value here
// :16:9: error: duplicate switch value
// :13:9: note: previous value here
