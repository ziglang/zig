comptime {
    const array = [2]u8{1, 2, 3};
    _ = array;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:31: error: index 2 outside array of size 2
