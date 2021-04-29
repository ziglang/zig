fn f(buf: []u8) void {
    var ptr = &buf[@sizeOf(u32)];
}

test "crash" {
    var buf: [4096]u8 = undefined;
    f(&buf);
}
