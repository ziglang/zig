const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "tuple concatenation" {
    const S = struct {
        fn doTheTest() void {
            var a: i32 = 1;
            var b: i32 = 2;
            var x = .{a};
            var y = .{b};
            var c = x ++ y;
            expectEqual(@as(i32, 1), c[0]);
            expectEqual(@as(i32, 2), c[1]);
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "tuple multiplication" {
    const S = struct {
        fn doTheTest() void {
            {
                const t = .{} ** 4;
                expectEqual(0, @typeInfo(@TypeOf(t)).Struct.fields.len);
            }
            {
                const t = .{'a'} ** 4;
                expectEqual(4, @typeInfo(@TypeOf(t)).Struct.fields.len);
                inline for (t) |x| expectEqual('a', x);
            }
            {
                const t = .{ 1, 2, 3 } ** 4;
                expectEqual(12, @typeInfo(@TypeOf(t)).Struct.fields.len);
                inline for (t) |x, i| expectEqual(1 + i % 3, x);
            }
        }
    };
    S.doTheTest();
    comptime S.doTheTest();

    const T = struct {
        fn consume_tuple(tuple: anytype, len: usize) void {
            expect(tuple.len == len);
        }

        fn doTheTest() void {
            const t1 = .{};

            var rt_var: u8 = 42;
            const t2 = .{rt_var} ++ .{};

            expect(t2.len == 1);
            expect(t2.@"0" == rt_var);
            expect(t2.@"0" == 42);
            expect(&t2.@"0" != &rt_var);

            consume_tuple(t1 ++ t1, 0);
            consume_tuple(.{} ++ .{}, 0);
            consume_tuple(.{0} ++ .{}, 1);
            consume_tuple(.{0} ++ .{1}, 2);
            consume_tuple(.{ 0, 1, 2 } ++ .{ u8, 1, noreturn }, 6);
            consume_tuple(t2 ++ t1, 1);
            consume_tuple(t1 ++ t2, 1);
            consume_tuple(t2 ++ t2, 2);
            consume_tuple(.{rt_var} ++ .{}, 1);
            consume_tuple(.{rt_var} ++ t1, 1);
            consume_tuple(.{} ++ .{rt_var}, 1);
            consume_tuple(t2 ++ .{void}, 2);
            consume_tuple(t2 ++ .{0}, 2);
            consume_tuple(.{0} ++ t2, 2);
            consume_tuple(.{void} ++ t2, 2);
            consume_tuple(.{u8} ++ .{rt_var} ++ .{true}, 3);
        }
    };

    T.doTheTest();
    comptime T.doTheTest();
}

test "pass tuple to comptime var parameter" {
    const S = struct {
        fn Foo(comptime args: anytype) void {
            expect(args[0] == 1);
        }

        fn doTheTest() void {
            Foo(.{1});
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}
