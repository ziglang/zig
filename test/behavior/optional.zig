const builtin = @import("builtin");
const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

test "passing an optional integer as a parameter" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn entry() bool {
            const x: i32 = 1234;
            return foo(x);
        }

        fn foo(x: ?i32) bool {
            return x.? == 1234;
        }
    };
    try expect(S.entry());
    comptime assert(S.entry());
}

pub const EmptyStruct = struct {};

test "optional pointer to size zero struct" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var e = EmptyStruct{};
    const o: ?*EmptyStruct = &e;
    try expect(o != null);
}

test "equality compare optional pointers" {
    try testNullPtrsEql();
    try comptime testNullPtrsEql();
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

test "optional with zero-bit type" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest(comptime ZeroBit: type, comptime zero_bit: ZeroBit) !void {
            const WithRuntime = struct {
                zero_bit: ZeroBit,
                runtime: u1,
            };
            var with_runtime: WithRuntime = undefined;
            with_runtime = .{ .zero_bit = zero_bit, .runtime = 0 };

            const Opt = struct { opt: ?ZeroBit };
            var opt: Opt = .{ .opt = null };
            try expect(opt.opt == null);
            try expect(opt.opt != zero_bit);
            try expect(opt.opt != with_runtime.zero_bit);
            opt.opt = zero_bit;
            try expect(opt.opt != null);
            try expect(opt.opt == zero_bit);
            try expect(opt.opt == with_runtime.zero_bit);
            opt = .{ .opt = zero_bit };
            try expect(opt.opt != null);
            try expect(opt.opt == zero_bit);
            try expect(opt.opt == with_runtime.zero_bit);
            opt.opt = with_runtime.zero_bit;
            try expect(opt.opt != null);
            try expect(opt.opt == zero_bit);
            try expect(opt.opt == with_runtime.zero_bit);
            opt = .{ .opt = with_runtime.zero_bit };
            try expect(opt.opt != null);
            try expect(opt.opt == zero_bit);
            try expect(opt.opt == with_runtime.zero_bit);

            var two: ?struct { ZeroBit, ZeroBit } = undefined;
            two = .{ with_runtime.zero_bit, with_runtime.zero_bit };
            try expect(two != null);
            try expect(two.?[0] == zero_bit);
            try expect(two.?[0] == with_runtime.zero_bit);
            try expect(two.?[1] == zero_bit);
            try expect(two.?[1] == with_runtime.zero_bit);
        }
    };

    try S.doTheTest(void, {});
    try comptime S.doTheTest(void, {});
    try S.doTheTest(enum { only }, .only);
    try comptime S.doTheTest(enum { only }, .only);
}

test "address of unwrap optional" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    _ = &s;
    try expect(s.x.?.y == 127);
}

test "equality compare optionals and non-optionals" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var five: isize = 5;
            var ten: isize = 10;
            var opt_null: ?isize = null;
            var opt_ten: ?isize = 10;
            _ = .{ &five, &ten, &opt_null, &opt_ten };
            try expect(opt_null != five);
            try expect(opt_null != ten);
            try expect(opt_ten != five);
            try expect(opt_ten == ten);

            var opt_int: ?isize = null;
            try expect(opt_int != five);
            try expect(opt_int != ten);
            try expect(opt_int == opt_null);
            try expect(opt_int != opt_ten);

            opt_int = 10;
            try expect(opt_int != five);
            try expect(opt_int == ten);
            try expect(opt_int != opt_null);
            try expect(opt_int == opt_ten);

            opt_int = five;
            try expect(opt_int == five);
            try expect(opt_int != ten);
            try expect(opt_int != opt_null);
            try expect(opt_int != opt_ten);

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
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "compare optionals with modified payloads" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var lhs: ?bool = false;
    const lhs_payload = &lhs.?;
    var rhs: ?bool = true;
    const rhs_payload = &rhs.?;
    try expect(lhs != rhs and !(lhs == rhs));

    lhs = null;
    lhs_payload.* = false;
    rhs = false;
    try expect(lhs != rhs and !(lhs == rhs));

    lhs = true;
    rhs = null;
    rhs_payload.* = true;
    try expect(lhs != rhs and !(lhs == rhs));

    lhs = null;
    lhs_payload.* = false;
    rhs = null;
    rhs_payload.* = true;
    try expect(lhs == rhs and !(lhs != rhs));
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
    try comptime S.entry();
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
    try comptime S.entry();
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

    const n = S.Node.new();
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
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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
    try comptime S.doTheTest();
}

test "0-bit child type coerced to optional return ptr result location" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var y = Foo{};
            const z = y.thing();
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
    try comptime S.doTheTest();
}

test "0-bit child type coerced to optional" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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
    try comptime S.doTheTest();
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
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        const I = extern struct { x: i128 };

        fn foo() ?I {
            var i: I = .{ .x = 1234 };
            _ = &i;
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

test "Optional slice passed to function" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        fn foo(a: ?[]const u8) !void {
            try std.testing.expectEqualStrings(a.?, "foo");
        }
        fn bar(a: ?[]allowzero const u8) !void {
            try std.testing.expectEqualStrings(@ptrCast(a.?), "bar");
        }
    };
    try S.foo("foo");
    try S.bar("bar");
}

test "peer type resolution in nested if expressions" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const Thing = struct { n: i32 };
    var a = false;
    var b = false;
    _ = .{ &a, &b };

    const result1 = if (a)
        Thing{ .n = 1 }
    else
        null;
    try expect(result1 == null);
    try expect(@TypeOf(result1) == ?Thing);

    const result2 = if (a)
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
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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

test "variable of optional of noreturn" {
    var null_opv: ?noreturn = null;
    _ = &null_opv;
    try std.testing.expectEqual(@as(?noreturn, null), null_opv);
}

test "copied optional doesn't alias source" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var opt_x: ?[3]f32 = [_]f32{0.0} ** 3;

    const x = opt_x.?;
    opt_x.?[0] = 15.0;

    try expect(x[0] == 0.0);
}

test "result location initialization of optional with OPV payload" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        x: u0,
    };

    const a: ?S = .{ .x = 0 };
    comptime assert(a.?.x == 0);

    comptime {
        var b: ?S = .{ .x = 0 };
        _ = &b;
        assert(b.?.x == 0);
    }

    var c: ?S = .{ .x = 0 };
    _ = &c;
    try expectEqual(0, (c orelse return error.TestFailed).x);
}
