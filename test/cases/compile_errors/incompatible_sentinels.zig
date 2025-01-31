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
    _ = &array;
}
export fn entry4() void {
    var array: [2:0]u8 = [_]u8{ 1, 2 };
    _ = &array;
}

// error
// backend=stage2
// target=native
//
// :4:12: error: expected type '[*:0]u8', found '[*:255]u8'
// :4:12: note: pointer sentinel '255' cannot cast into pointer sentinel '0'
// :3:34: note: function return type declared here
// :7:12: error: expected type '[*:0]u8', found '[*]u8'
// :7:12: note: destination pointer requires '0' sentinel
// :6:30: note: function return type declared here
// :10:35: error: expected type '[2:0]u8', found '[2:255]u8'
// :10:35: note: array sentinel '255' cannot cast into array sentinel '0'
// :14:31: error: expected type '[2:0]u8', found '[2]u8'
// :14:31: note: destination array requires '0' sentinel
