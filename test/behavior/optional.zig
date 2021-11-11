const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "passing an optional integer as a parameter" {
    const S = struct {
        fn entry() bool {
            var x: i32 = 1234;
            return foo(x);
        }

        fn foo(x: ?i32) bool {
            return x.? == 1234;
        }
    };
    try expect(S.entry());
    comptime try expect(S.entry());
}

test "self-referential struct through a slice of optional" {
    const S = struct {
        const Node = struct {
            children: []?Node,
            data: ?u8,

            fn new() Node {
                return Node{
                    .children = undefined,
                    .data = null,
                };
            }
        };
    };

    var n = S.Node.new();
    try expect(n.data == null);
}

pub const EmptyStruct = struct {};

test "optional pointer to size zero struct" {
    var e = EmptyStruct{};
    var o: ?*EmptyStruct = &e;
    try expect(o != null);
}

test "equality compare optional pointers" {
    try testNullPtrsEql();
    comptime try testNullPtrsEql();
}

fn testNullPtrsEql() !void {
    var number: i32 = 1234;

    var x: ?*i32 = null;
    var y: ?*i32 = null;
    try expect(x == y);
    y = &number;
    try expect(x != y);
    try expect(x != &number);
    try expect(&number != x);
    x = &number;
    try expect(x == y);
    try expect(x == &number);
    try expect(&number == x);
}

test "optional with void type" {
    const Foo = struct {
        x: ?void,
    };
    var x = Foo{ .x = null };
    try expect(x.x == null);
}

test "address of unwrap optional" {
    const S = struct {
        const Foo = struct {
            a: i32,
        };

        var global: ?Foo = null;

        pub fn getFoo() anyerror!*Foo {
            return &global.?;
        }
    };
    S.global = S.Foo{ .a = 1234 };
    const foo = S.getFoo() catch unreachable;
    try expect(foo.a == 1234);
}

test "nested optional field in struct" {
    const S2 = struct {
        y: u8,
    };
    const S1 = struct {
        x: ?S2,
    };
    var s = S1{
        .x = S2{ .y = 127 },
    };
    try expect(s.x.?.y == 127);
}
