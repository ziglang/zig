const builtin = @import("builtin");
const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

test "passing an optional integer as a parameter" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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

pub const EmptyStruct = struct {};

test "optional pointer to size zero struct" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const Foo = struct {
        x: ?void,
    };
    var x = Foo{ .x = null };
    try expect(x.x == null);
}

test "address of unwrap optional" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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

test "equality compare optional with non-optional" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try test_cmp_optional_non_optional();
    comptime try test_cmp_optional_non_optional();
}

fn test_cmp_optional_non_optional() !void {
    var ten: i32 = 10;
    var opt_ten: ?i32 = 10;
    var five: i32 = 5;
    var int_n: ?i32 = null;

    try expect(int_n != ten);
    try expect(opt_ten == ten);
    try expect(opt_ten != five);

    // test evaluation is always lexical
    // ensure that the optional isn't always computed before the non-optional
    var mutable_state: i32 = 0;
    _ = blk1: {
        mutable_state += 1;
        break :blk1 @as(?f64, 10.0);
    } != blk2: {
        try expect(mutable_state == 1);
        break :blk2 @as(f64, 5.0);
    };
    _ = blk1: {
        mutable_state += 1;
        break :blk1 @as(f64, 10.0);
    } != blk2: {
        try expect(mutable_state == 2);
        break :blk2 @as(?f64, 5.0);
    };
}

test "unwrap function call with optional pointer return value" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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

test "self-referential struct through a slice of optional" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    try expect(Enum.one == values[i].?.Num);
    i += 1;
    try expect(Enum.two == values[i].?.Num);
    i += 1;
    try expect(Enum.three == values[i].?.Num);
    i += 1;
    try expect(Enum.one == values[i].?.Num);
    i += 1;
    try expect(Enum.two == values[i].?.Num);
    i += 1;
    try expect(Enum.three == values[i].?.Num);
}

test "optional pointer to zero bit optional payload" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const B = struct {
        fn foo(_: *@This()) void {}
    };
    const A = struct {
        b: ?B = .{},
    };
    var a: A = .{};
    var a_ptr = &a;
    if (a_ptr.b) |*some| {
        some.foo();
    }
}

test "optional pointer to zero bit error union payload" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const B = struct {
        fn foo(_: *@This()) void {}
    };
    const A = struct {
        b: anyerror!B = .{},
    };
    var a: A = .{};
    var a_ptr = &a;
    if (a_ptr.b) |*some| {
        some.foo();
    } else |_| {}
}

const NoReturn = struct {
    var a: u32 = undefined;
    fn someData() bool {
        a -= 1;
        return a == 0;
    }
    fn loop() ?noreturn {
        while (true) {
            if (someData()) return null;
        }
    }
    fn testOrelse() u32 {
        loop() orelse return 123;
        @compileError("bad");
    }
};

test "optional of noreturn used with if" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    NoReturn.a = 64;
    if (NoReturn.loop()) |_| {
        @compileError("bad");
    } else {
        try expect(true);
    }
}

test "optional of noreturn used with orelse" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    NoReturn.a = 64;
    const val = NoReturn.testOrelse();
    try expect(val == 123);
}

test "orelse on C pointer" {
    // TODO https://github.com/ziglang/zig/issues/6597
    const foo: [*c]const u8 = "hey";
    const d = foo orelse @compileError("bad");
    try expectEqual([*c]const u8, @TypeOf(d));
}

test "alignment of wrapping an optional payload" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        const I = extern struct { x: i128 };

        fn foo() ?I {
            var i: I = .{ .x = 1234 };
            return i;
        }
    };
    try expect(S.foo().?.x == 1234);
}

test "Optional slice size is optimized" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(@sizeOf(?[]u8) == @sizeOf([]u8));
    var a: ?[]const u8 = null;
    try expect(a == null);
    a = "hello";
    try expectEqualStrings(a.?, "hello");
}

test "peer type resolution in nested if expressions" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const Thing = struct { n: i32 };
    var a = false;
    var b = false;

    var result1 = if (a)
        Thing{ .n = 1 }
    else
        null;
    try expect(result1 == null);
    try expect(@TypeOf(result1) == ?Thing);

    var result2 = if (a)
        Thing{ .n = 0 }
    else if (b)
        Thing{ .n = 1 }
    else
        null;
    try expect(result2 == null);
    try expect(@TypeOf(result2) == ?Thing);
}

test "cast slice to const slice nested in error union and optional" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const S = struct {
        fn inner() !?[]u8 {
            return error.Foo;
        }
        fn outer() !?[]const u8 {
            return inner();
        }
    };
    try std.testing.expectError(error.Foo, S.outer());
}
