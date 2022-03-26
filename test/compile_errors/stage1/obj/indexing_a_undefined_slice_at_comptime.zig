comptime {
    var slice: []u8 = undefined;
    slice[0] = 2;
}

// indexing a undefined slice at comptime
//
// tmp.zig:3:10: error: index 0 outside slice of size 0
