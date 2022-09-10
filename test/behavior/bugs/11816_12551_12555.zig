const std = @import("std");

test "issue11816" {
    var x: u32 = 3;
    const val: usize = while (true) switch (x) {
        1 => break 2,
        else => x -= 1,
    }; // else unreachable; another bug?
    try std.testing.expectEqual(@as(usize, 2), val);
}

test "issue12551_12555" {
    try std.testing.expect(for ([1]u8{0}) |x| {
        if (x == 0) break true;
    } else false);
}
