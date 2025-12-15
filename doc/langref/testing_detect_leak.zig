const std = @import("std");

test "detect leak" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(u21) = .empty;
    // missing `defer list.deinit(gpa);`
    try list.append(gpa, '☔');

    try std.testing.expect(list.items.len == 1);
}

// test_error=1 tests leaked memory
