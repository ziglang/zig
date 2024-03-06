comptime {
    var array = [_:0]u8{ 1, 2, 3, 4 };
    var src_slice: [:0]u8 = &array;
    const slice = src_slice[2..6];
    _ = slice;
}
comptime {
    var array = [_:0]u8{ 1, 2, 3, 4 };
    const slice = array[2..6];
    _ = slice;
}
comptime {
    var array = [_]u8{ 1, 2, 3, 4 };
    const slice = array[2..5];
    _ = slice;
}
comptime {
    var array = [_:0]u8{ 1, 2, 3, 4 };
    const slice = array[3..2];
    _ = slice;
}

// error
// target=native
//
// :4:32: error: end index 6 out of bounds for slice of length 4 +1 (sentinel)
// :9:28: error: end index 6 out of bounds for array of length 4 +1 (sentinel)
// :14:28: error: end index 5 out of bounds for array of length 4
// :19:25: error: start index 3 is larger than end index 2
