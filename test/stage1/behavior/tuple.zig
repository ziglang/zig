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

    const T = struct {
        fn consume_tuple(tuple: var, len: usize) void {
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
            consume_tuple(.{0, 1, 2} ++ .{u8, 1, noreturn}, 6);
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
