comptime {
    var c_ptr: [*c]u8 = 0;
    const zig_ptr: *u8 = c_ptr;
    _ = &c_ptr;
    _ = zig_ptr;
}

// error
// backend=stage2
// target=native
//
// :3:26: error: null pointer casted to type '*u8'
