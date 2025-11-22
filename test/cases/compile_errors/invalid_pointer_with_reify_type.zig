export fn entry() void {
    _ = @Pointer(.one, .{}, u8, 0);
}

// error
//
// :2:33: error: sentinels are only allowed on slices and unknown-length pointers
