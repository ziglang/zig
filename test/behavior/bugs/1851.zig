const std = @import("std");
const expect = std.testing.expect;

test "allocation and looping over 3-byte integer" {
    try expect(@sizeOf(u24) == 4);
    try expect(@sizeOf([1]u24) == 4);
    try expect(@alignOf(u24) == 4);
    try expect(@alignOf([1]u24) == 4);

    var x = try std.testing.allocator.alloc(u24, 2);
    defer std.testing.allocator.free(x);
    try expect(x.len == 2);
    x[0] = 0xFFFFFF;
    x[1] = 0xFFFFFF;

    const bytes = std.mem.sliceAsBytes(x);
    try expect(@TypeOf(bytes) == []align(4) u8);
    try expect(bytes.len == 8);

    for (bytes) |*b| {
        b.* = 0x00;
    }

    try expect(x[0] == 0x00);
    try expect(x[1] == 0x00);
}
