const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "unwrap function call with optional pointer return value" {
    const S = struct {
        fn entry() !void {
            try expect(foo().?.* == 1234);
            try expect(bar() == null);
        }
        const global: i32 = 1234;
        fn foo() ?*const i32 {
            return &global;
        }
        fn bar() ?*i32 {
            return null;
        }
    };
    try S.entry();
    comptime try S.entry();
}

test "nested orelse" {
    const S = struct {
        fn entry() !void {
            try expect(func() == null);
        }
        fn maybe() ?Foo {
            return null;
        }
        fn func() ?Foo {
            const x = maybe() orelse
                maybe() orelse
                return null;
            _ = x;
            unreachable;
        }
        const Foo = struct {
            field: i32,
        };
    };
    try S.entry();
    comptime try S.entry();
}

test "assigning to an unwrapped optional field in an inline loop" {
    comptime var maybe_pos_arg: ?comptime_int = null;
    inline for ("ab") |x| {
        _ = x;
        maybe_pos_arg = 0;
        if (maybe_pos_arg.? != 0) {
            @compileError("bad");
        }
        maybe_pos_arg.? = 10;
    }
}

test "coerce an anon struct literal to optional struct" {
    const S = struct {
        const Struct = struct {
            field: u32,
        };
        fn doTheTest() !void {
            var maybe_dims: ?Struct = null;
            maybe_dims = .{ .field = 1 };
            try expect(maybe_dims.?.field == 1);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "0-bit child type coerced to optional return ptr result location" {
    const S = struct {
        fn doTheTest() !void {
            var y = Foo{};
            var z = y.thing();
            try expect(z != null);
        }

        const Foo = struct {
            pub const Bar = struct {
                field: *Foo,
            };

            pub fn thing(self: *Foo) ?Bar {
                return Bar{ .field = self };
            }
        };
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "0-bit child type coerced to optional" {
    const S = struct {
        fn doTheTest() !void {
            var it: Foo = .{
                .list = undefined,
            };
            try expect(it.foo() != null);
        }

        const Empty = struct {};
        const Foo = struct {
            list: [10]Empty,

            fn foo(self: *Foo) ?*Empty {
                const data = &self.list[0];
                return data;
            }
        };
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "array of optional unaligned types" {
    const Enum = enum { one, two, three };

    const SomeUnion = union(enum) {
        Num: Enum,
        Other: u32,
    };

    const values = [_]?SomeUnion{
        SomeUnion{ .Num = .one },
        SomeUnion{ .Num = .two },
        SomeUnion{ .Num = .three },
        SomeUnion{ .Num = .one },
        SomeUnion{ .Num = .two },
        SomeUnion{ .Num = .three },
    };

    // The index must be a runtime value
    var i: usize = 0;
    try expectEqual(Enum.one, values[i].?.Num);
    i += 1;
    try expectEqual(Enum.two, values[i].?.Num);
    i += 1;
    try expectEqual(Enum.three, values[i].?.Num);
    i += 1;
    try expectEqual(Enum.one, values[i].?.Num);
    i += 1;
    try expectEqual(Enum.two, values[i].?.Num);
    i += 1;
    try expectEqual(Enum.three, values[i].?.Num);
}
