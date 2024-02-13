comptime {
    var x: [*c]u8 = null;
    var runtime_len: usize = 0;
    _ = &runtime_len;
    _ = x[0..runtime_len];
}

// error
// target=native
//
// :5:10: error: slice of null pointer
