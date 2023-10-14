const foo = @import("foo");
comptime {
    _ = foo;
}

// error
// backend=stage2
// target=native
//
// :1:21: error: no module named 'foo' available within module root
