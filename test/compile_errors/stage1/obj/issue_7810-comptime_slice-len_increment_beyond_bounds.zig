export fn foo_slice_len_increment_beyond_bounds() void {
    comptime {
        var buf_storage: [8]u8 = undefined;
        var buf: []const u8 = buf_storage[0..];
        buf.len += 1;
        buf[8] = 42;
    }
}

// comptime slice-len increment beyond bounds
//
// :6:12: error: out of bounds slice
