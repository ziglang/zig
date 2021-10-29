const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "if copies its payload" {
    const S = struct {
        fn doTheTest() !void {
            var tmp: ?i32 = 10;
            if (tmp) |value| {
                // Modify the original variable
                tmp = null;
                try expect(value == 10);
            } else unreachable;
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}
