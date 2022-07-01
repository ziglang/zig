comptime {
    var slice: []u8 = undefined;
    slice[0] = 2;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:10: error: index 0 outside slice of size 0
