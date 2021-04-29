fn foo(a: []u8) void {}

test "address of 0 length array" {
    var pt: [0]u8 = undefined;
    foo(&pt);
}
