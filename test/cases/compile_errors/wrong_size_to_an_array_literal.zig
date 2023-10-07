comptime {
    const array = [2]u8{ 1, 2, 3 };
    _ = array;
}

// error
// backend=stage2
// target=native
//
// :2:24: error: expected 2 array elements; found 3
