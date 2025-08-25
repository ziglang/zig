const foo = [3]u16{ .x = 1024 };
comptime {
    _ = foo;
}

// error
// backend=stage2
// target=native
//
// :1:13: error: initializing array with struct syntax
