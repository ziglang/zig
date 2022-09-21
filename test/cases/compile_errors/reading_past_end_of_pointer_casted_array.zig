comptime {
    const array: [4]u8 = "aoeu".*;
    const sub_array = array[1..];
    const int_ptr = @ptrCast(*const u24, @alignCast(@alignOf(u24), sub_array));
    const deref = int_ptr.*;
    _ = deref;
}

// error
// backend=stage2
// target=native
//
// :5:26: error: dereference of '*const u24' exceeds bounds of containing decl of type '[4]u8'
