export fn foo_slice_len_increment_beyond_bounds() void {
    comptime {
        var buf_storage: [8]u8 = undefined;
        var buf: []u8 = buf_storage[0..];
        buf.len += 1;
        buf[8] = 42;
    }
}

// error
// backend=stage2
// target=native
//
// :6:16: error: comptime store of index 8 out of bounds of array length 8
