comptime {
    var a: []u8 = undefined;
    var b = a[0..10];
    _ = b;
}

// comptime slice of an undefined slice
//
// tmp.zig:3:14: error: slice of undefined
