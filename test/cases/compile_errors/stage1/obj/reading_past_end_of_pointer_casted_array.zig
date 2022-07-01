comptime {
    const array: [4]u8 = "aoeu".*;
    const sub_array = array[1..];
    const int_ptr = @ptrCast(*const u24, sub_array);
    const deref = int_ptr.*;
    _ = deref;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:5:26: error: attempt to read 4 bytes from [4]u8 at index 1 which is 3 bytes
