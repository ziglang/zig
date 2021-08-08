const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "const result loc, runtime if cond, else unreachable" {
    const Num = enum {
        One,
        Two,
    };

    var t = true;
    const x = if (t) Num.Two else unreachable;
    try expect(x == .Two);
}

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

test "while copies its payload" {
    const S = struct {
        fn doTheTest() !void {
            var tmp: ?i32 = 10;
            if (tmp) |value| {
                // Modify the original variable
                tmp = null;
                try expectEqual(@as(i32, 10), value);
            } else unreachable;
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}
