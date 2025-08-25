comptime {
    const array: [4]u8 = "aoeu".*;
    const sub_array = array[1..];
    const int_ptr: *const u24 = @ptrCast(@alignCast(sub_array));
    const deref = int_ptr.*;
    _ = deref;
}
comptime {
    const array: [4]u8 = "aoeu".*;
    const sub_array = array[1..];
    const int_ptr: *const u32 = @ptrCast(@alignCast(sub_array));
    const deref = int_ptr.*;
    _ = deref;
}

// error
// backend=stage2
// target=native
//
// :5:26: error: dereference of '*const u24' exceeds bounds of containing decl of type '[4]u8'
// :12:26: error: dereference of '*const u32' exceeds bounds of containing decl of type '[4]u8'
