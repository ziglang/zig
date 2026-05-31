comptime {
    _ = 1[0..];
}

// error
//
// :2:10: error: slice of non-array type 'comptime_int'
