const std = @import("std");
const mod2 = @import("module2");

pub fn main() !void {
    try std.testing.expectEqual(@as(usize, 1234567890), mod2.mod1.decl);
    for (@import("builtin").test_functions) |test_fn| {
        try test_fn.func();
    }
}
