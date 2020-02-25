const std = @import("std");
const expect = std.testing.expect;

test "allocation and looping over 3-byte integer" {
    expect(@sizeOf(u24) == 4);
    expect(@sizeOf([1]u24) == 4);
    expect(@alignOf(u24) == 4);
    expect(@alignOf([1]u24) == 4);

    var x = try std.testing.allocator.alloc(u24, 2);
    defer std.testing.allocator.free(x);
    expect(x.len == 2);
    x[0] = 0xFFFFFF;
    x[1] = 0xFFFFFF;

    const bytes = std.mem.sliceAsBytes(x);
    expect(@TypeOf(bytes) == []align(4) u8);
    expect(bytes.len == 8);

    for (bytes) |*b| {
        b.* = 0x00;
    }

    expect(x[0] == 0x00);
    expect(x[1] == 0x00);
}
