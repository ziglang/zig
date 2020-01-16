const std = @import("std");
const expect = std.testing.expect;

test "tuple concatenation" {
    const S = struct {
        fn doTheTest() void {
            var a: i32 = 1;
            var b: i32 = 2;
            var x = .{a};
            var y = .{b};
            var c = x ++ y;
            expect(c[0] == 1);
            expect(c[1] == 2);
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}
