export fn concat_of_empty_slice_len_increment_beyond_bounds() void {
    comptime {
        var list: []u8 = &.{};
        list.len += 1;
        list = list ++ list;
    }
}

// error
//
// :5:16: error: dereference of '*[1]u8' exceeds bounds of containing decl of type '[0]u8'
