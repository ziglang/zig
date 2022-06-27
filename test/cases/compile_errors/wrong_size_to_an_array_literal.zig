comptime {
    const array = [2]u8{1, 2, 3};
    _ = array;
}

// error
// backend=stage2
// target=native
//
// :2:31: error: index 2 outside array of length 2
