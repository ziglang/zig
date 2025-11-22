const std = @import("std");

test "detect leak" {
    const allocator = std.testing.allocator;
    var list = try std.ArrayList(u21).initCapacity(allocator, 1);
    // missing `defer list.deinit(allocator);`
    try list.append(allocator, '☔');

    try std.testing.expect(list.items.len == 1);
}

// test_error=1 tests leaked memory
