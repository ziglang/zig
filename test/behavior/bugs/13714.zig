comptime {
    var image: [1]u8 = undefined;
    _ = @shlExact(@as(u16, image[0]), 8);
}
