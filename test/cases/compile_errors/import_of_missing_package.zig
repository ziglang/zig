const foo = @import("foo");
comptime {
    _ = foo;
}

// error
// backend=stage2
// target=native
//
// :1:21: error: no package named 'foo' available within package 'root'
