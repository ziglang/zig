export fn entry() void {
    _ = @Type(.{ .Pointer = .{
        .size = .One,
        .is_const = false,
        .is_volatile = false,
        .alignment = 1,
        .address_space = .generic,
        .child = u8,
        .is_allowzero = false,
        .sentinel = &@as(u8, 0),
    } });
}

// error
// backend=stage2
// target=native
//
// :2:9: error: sentinels are only allowed on slices and unknown-length pointers
