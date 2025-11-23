const std = @import("std");

test "detect leak" {
    const allocator = std.testing.allocator;
    var list: std.ArrayList(u21) = .empty;
    // missing `defer list.deinit(allocator);`
    try list.append(allocator, '☔');

    try std.testing.expect(list.items.len == 1);
}

// test_error=1 tests leaked memory
