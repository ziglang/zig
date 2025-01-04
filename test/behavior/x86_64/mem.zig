fn access(comptime array: anytype) !void {
    var slice: []const @typeInfo(@TypeOf(array)).array.child = undefined;
    slice = &array;
    inline for (0.., &array) |ct_index, *elem| {
        var rt_index: usize = undefined;
        rt_index = ct_index;
        if (&slice.ptr[ct_index] != elem) return error.Unexpected;
        if (&slice[ct_index] != elem) return error.Unexpected;
        if (&slice.ptr[rt_index] != elem) return error.Unexpected;
        if (&slice[rt_index] != elem) return error.Unexpected;
        if (slice.ptr[ct_index] != elem.*) return error.Unexpected;
        if (slice[ct_index] != elem.*) return error.Unexpected;
        if (slice.ptr[rt_index] != elem.*) return error.Unexpected;
        if (slice[rt_index] != elem.*) return error.Unexpected;
    }
}
test access {
    try access([3]u8{ 0xdb, 0xef, 0xbd });
    try access([3]u16{ 0x340e, 0x3654, 0x88d7 });
    try access([3]u32{ 0xd424c2c0, 0x2d6ac466, 0x5a0cfaba });
    try access([3]u64{
        0x9327a4f5221666a6,
        0x5c34d3ddd84a8b12,
        0xbae087f39f649260,
    });
    try access([3]u128{
        0x601cf010065444d4d42d5536dd9b95db,
        0xa03f592fcaa22d40af23a0c735531e3c,
        0x5da44907b31602b95c2d93f0b582ceab,
    });
}
