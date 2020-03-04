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

test "tuple initialization with structure initializer and constant expression" {
    const TestStruct = struct {
        state: u8,
    };

    const S = struct {
        fn doTheTest() void {
            const tuple_with_struct = .{ TestStruct{ .state = 42 }, 0 };
            expect(tuple_with_struct.len == 2);
            expect(tuple_with_struct[0].state == 42);
            expect(tuple_with_struct[1] == 0);
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "passing tuples as comptime generic parameters" {
    const S = struct {
        fn expect_len(comptime pack: var, comptime len: usize) void {
            expect(pack.len == len);
        }

        fn expect_first_element(comptime pack: var, comptime elem: var) void {
            expect(pack[0] == elem);
        }

        fn doTheTest() void {
            expect_len(.{}, 0);
            expect_len(.{ 0 }, 1);
            expect_first_element(.{ 0 }, 0);
            expect_len(.{ u8, 1, "literal" }, 3);
            expect_first_element(.{ u8, 1, "literal" }, u8);
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}
