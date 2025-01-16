export fn entry() void {
    _ = @Type(.{ .pointer = .{
        .size = .one,
        .is_const = false,
        .is_volatile = false,
        .alignment = 1,
        .address_space = .generic,
        .child = u8,
        .is_allowzero = false,
        .sentinel_ptr = &@as(u8, 0),
    } });
}

// error
//
// :2:9: error: sentinels are only allowed on slices and unknown-length pointers
