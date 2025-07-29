const foo = @import("foo");
comptime {
    _ = foo;
}

// error
//
// :1:21: error: no module named 'foo' available within module 'root'
