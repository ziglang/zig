const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "if prongs cast to expected type instead of peer type resolution" {
    const S = struct {
        fn doTheTest(f: bool) !void {
            var x: i32 = 0;
            x = if (f) 1 else 2;
            try expect(x == 2);

            var b = true;
            const y: i32 = if (b) 1 else 2;
            try expect(y == 1);
        }
    };
    try S.doTheTest(false);
    comptime try S.doTheTest(false);
}
