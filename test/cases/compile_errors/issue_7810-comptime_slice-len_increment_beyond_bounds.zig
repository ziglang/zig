export fn foo_slice_len_increment_beyond_bounds() void {
    comptime {
        var buf_storage: [8]u8 = undefined;
        var buf: []u8 = buf_storage[0..];
        buf.len += 1;
        buf[8] = 42;
    }
}

// error
//
// :6:16: error: dereference of '*u8' exceeds bounds of containing decl of type '[8]u8'
