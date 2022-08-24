comptime {
    _ = 1[0..];
}

// error
// backend=stage2
// target=native
//
// :2:10: error: slice of non-array type 'comptime_int'
