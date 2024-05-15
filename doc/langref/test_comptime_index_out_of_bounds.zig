comptime {
    const array: [5]u8 = "hello".*;
    const garbage = array[5];
    _ = garbage;
}

// test_error=index 5 outside array of length 5
