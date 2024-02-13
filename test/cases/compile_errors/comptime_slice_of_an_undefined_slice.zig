comptime {
    var a: []u8 = undefined;
    var b = a[0..10];
    _ = &b;
}

// error
// backend=stage2
// target=native
//
// :3:14: error: slice of undefined
