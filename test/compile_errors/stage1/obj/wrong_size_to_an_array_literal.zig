comptime {
    const array = [2]u8{1, 2, 3};
    _ = array;
}

// wrong size to an array literal
//
// tmp.zig:2:31: error: index 2 outside array of size 2
