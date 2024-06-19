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
// :4:32: error: slice end out of bounds: end 6, length 5
// :9:28: error: slice end out of bounds: end 6, length 5
// :14:28: error: slice end out of bounds: end 5, length 4
// :19:25: error: bounds out of order: start 3, end 2
