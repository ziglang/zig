const mod2 = @import("module2");
const std = @import("std");

test {
    try std.testing.expectEqual(@as(usize, 1234567890), mod2.mod1.decl);
}
