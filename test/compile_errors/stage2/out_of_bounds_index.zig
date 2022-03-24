comptime {
    var array = [_:0]u8{ 1, 2, 3, 4 };
    var src_slice: [:0]u8 = &array;
    var slice = src_slice[2..6];
    _ = slice;
}
comptime {
    var array = [_:0]u8{ 1, 2, 3, 4 };
    var slice = array[2..6];
    _ = slice;
}
comptime {
    var array = [_]u8{ 1, 2, 3, 4 };
    var slice = array[2..5];
    _ = slice;
}
comptime {
    var array = [_:0]u8{ 1, 2, 3, 4 };
    var slice = array[3..2];
    _ = slice;
}

// out of bounds indexing
//
// :4:26: error: end index 6 out of bounds for slice of length 4 +1 (sentinel)
// :9:22: error: end index 6 out of bounds for array of length 4 +1 (sentinel)
// :14:22: error: end index 5 out of bounds for array of length 4
// :19:22: error: start index 3 is larger than end index 2
