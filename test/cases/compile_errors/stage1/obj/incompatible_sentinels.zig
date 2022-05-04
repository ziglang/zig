// Note: One of the error messages here is backwards. It would be nice to fix, but that's not
// going to stop me from merging this branch which fixes a bunch of other stuff.
export fn entry1(ptr: [*:255]u8) [*:0]u8 {
    return ptr;
}
export fn entry2(ptr: [*]u8) [*:0]u8 {
    return ptr;
}
export fn entry3() void {
    var array: [2:0]u8 = [_:255]u8{ 1, 2 };
    _ = array;
}
export fn entry4() void {
    var array: [2:0]u8 = [_]u8{ 1, 2 };
    _ = array;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:12: error: expected type '[*:0]u8', found '[*:255]u8'
// tmp.zig:4:12: note: destination pointer requires a terminating '0' sentinel, but source pointer has a terminating '255' sentinel
// tmp.zig:7:12: error: expected type '[*:0]u8', found '[*]u8'
// tmp.zig:7:12: note: destination pointer requires a terminating '0' sentinel
// tmp.zig:10:35: error: expected type '[2:255]u8', found '[2:0]u8'
// tmp.zig:10:35: note: destination array requires a terminating '255' sentinel, but source array has a terminating '0' sentinel
// tmp.zig:14:31: error: expected type '[2:0]u8', found '[2]u8'
// tmp.zig:14:31: note: destination array requires a terminating '0' sentinel
