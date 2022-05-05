comptime {
    var a: []u8 = undefined;
    var b = a[0..10];
    _ = b;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:14: error: slice of undefined
