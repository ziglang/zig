const builtin = @import("builtin");
const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectEqual = std.testing.expectEqual;

test "tuple concatenation" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var a: i32 = 1;
            var b: i32 = 2;
            var x = .{a};
            var y = .{b};
            var c = x ++ y;
            try expect(@as(i32, 1) == c[0]);
            try expect(@as(i32, 2) == c[1]);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "tuple multiplication" {
    const S = struct {
        fn doTheTest() !void {
            {
                const t = .{} ** 4;
                try expect(@typeInfo(@TypeOf(t)).Struct.fields.len == 0);
            }
            {
                const t = .{'a'} ** 4;
                try expect(@typeInfo(@TypeOf(t)).Struct.fields.len == 4);
                inline for (t) |x| try expect(x == 'a');
            }
            {
                const t = .{ 1, 2, 3 } ** 4;
                try expect(@typeInfo(@TypeOf(t)).Struct.fields.len == 12);
                inline for (t, 0..) |x, i| try expect(x == 1 + i % 3);
            }
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "more tuple concatenation" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const T = struct {
        fn consume_tuple(tuple: anytype, len: usize) !void {
            try expect(tuple.len == len);
        }

        fn doTheTest() !void {
            const t1 = .{};

            var rt_var: u8 = 42;
            const t2 = .{rt_var} ++ .{};

            try expect(t2.len == 1);
            try expect(t2.@"0" == rt_var);
            try expect(t2.@"0" == 42);
            try expect(&t2.@"0" != &rt_var);

            try consume_tuple(t1 ++ t1, 0);
            try consume_tuple(.{} ++ .{}, 0);
            try consume_tuple(.{0} ++ .{}, 1);
            try consume_tuple(.{0} ++ .{1}, 2);
            try consume_tuple(.{ 0, 1, 2 } ++ .{ u8, 1, noreturn }, 6);
            try consume_tuple(t2 ++ t1, 1);
            try consume_tuple(t1 ++ t2, 1);
            try consume_tuple(t2 ++ t2, 2);
            try consume_tuple(.{rt_var} ++ .{}, 1);
            try consume_tuple(.{rt_var} ++ t1, 1);
            try consume_tuple(.{} ++ .{rt_var}, 1);
            try consume_tuple(t2 ++ .{void}, 2);
            try consume_tuple(t2 ++ .{0}, 2);
            try consume_tuple(.{0} ++ t2, 2);
            try consume_tuple(.{void} ++ t2, 2);
            try consume_tuple(.{u8} ++ .{rt_var} ++ .{true}, 3);
        }
    };

    try T.doTheTest();
    comptime try T.doTheTest();
}

test "pass tuple to comptime var parameter" {
    const S = struct {
        fn Foo(comptime args: anytype) !void {
            try expect(args[0] == 1);
        }

        fn doTheTest() !void {
            try Foo(.{1});
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "tuple initializer for var" {
    const S = struct {
        fn doTheTest() void {
            const Bytes = struct {
                id: usize,
            };

            var tmp = .{
                .id = @as(usize, 2),
                .name = Bytes{ .id = 20 },
            };
            _ = tmp;
        }
    };

    S.doTheTest();
    comptime S.doTheTest();
}

test "array-like initializer for tuple types" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const T = @Type(.{
        .Struct = .{
            .is_tuple = true,
            .layout = .Auto,
            .decls = &.{},
            .fields = &.{
                .{
                    .name = "0",
                    .type = i32,
                    .default_value = null,
                    .is_comptime = false,
                    .alignment = @alignOf(i32),
                },
                .{
                    .name = "1",
                    .type = u8,
                    .default_value = null,
                    .is_comptime = false,
                    .alignment = @alignOf(i32),
                },
            },
        },
    });
    const S = struct {
        fn doTheTest() !void {
            var obj: T = .{ -1234, 128 };
            try expect(@as(i32, -1234) == obj[0]);
            try expect(@as(u8, 128) == obj[1]);
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
}

test "anon struct as the result from a labeled block" {
    const S = struct {
        fn doTheTest() !void {
            const precomputed = comptime blk: {
                var x: i32 = 1234;
                break :blk .{
                    .x = x,
                };
            };
            try expect(precomputed.x == 1234);
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
}

test "tuple as the result from a labeled block" {
    const S = struct {
        fn doTheTest() !void {
            const precomputed = comptime blk: {
                var x: i32 = 1234;
                break :blk .{x};
            };
            try expect(precomputed[0] == 1234);
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
}

test "initializing tuple with explicit type" {
    const T = @TypeOf(.{ @as(i32, 0), @as(u32, 0) });
    var a = T{ 0, 0 };
    _ = a;
}

test "initializing anon struct with explicit type" {
    const T = @TypeOf(.{ .foo = @as(i32, 1), .bar = @as(i32, 2) });
    var a = T{ .foo = 1, .bar = 2 };
    _ = a;
}

test "fieldParentPtr of tuple" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var x: u32 = 0;
    const tuple = .{ x, x };
    try testing.expect(&tuple == @fieldParentPtr(@TypeOf(tuple), "1", &tuple[1]));
}

test "fieldParentPtr of anon struct" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var x: u32 = 0;
    const anon_st = .{ .foo = x, .bar = x };
    try testing.expect(&anon_st == @fieldParentPtr(@TypeOf(anon_st), "bar", &anon_st.bar));
}

test "offsetOf tuple" {
    var x: u32 = 0;
    const T = @TypeOf(.{ x, x });
    try expect(@offsetOf(T, "1") == @sizeOf(u32));
}

test "offsetOf anon struct" {
    var x: u32 = 0;
    const T = @TypeOf(.{ .foo = x, .bar = x });
    try expect(@offsetOf(T, "bar") == @sizeOf(u32));
}

test "initializing tuple with mixed comptime-runtime fields" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    var x: u32 = 15;
    const T = @TypeOf(.{ @as(i32, -1234), @as(u32, 5678), x });
    var a: T = .{ -1234, 5678, x + 1 };
    try expect(a[2] == 16);
}

test "initializing anon struct with mixed comptime-runtime fields" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    var x: u32 = 15;
    const T = @TypeOf(.{ .foo = @as(i32, -1234), .bar = x });
    var a: T = .{ .foo = -1234, .bar = x + 1 };
    try expect(a.bar == 16);
}

test "tuple in tuple passed to generic function" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn pair(x: f32, y: f32) std.meta.Tuple(&.{ f32, f32 }) {
            return .{ x, y };
        }

        fn foo(x: anytype) !void {
            try expect(x[0][0] == 1.5);
            try expect(x[0][1] == 2.5);
        }
    };
    const x = comptime S.pair(1.5, 2.5);
    try S.foo(.{x});
}

test "coerce tuple to tuple" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const T = std.meta.Tuple(&.{u8});
    const S = struct {
        fn foo(x: T) !void {
            try expect(x[0] == 123);
        }
    };
    try S.foo(.{123});
}

test "tuple type with void field" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    const T = std.meta.Tuple(&[_]type{void});
    const x = T{{}};
    try expect(@TypeOf(x[0]) == void);
}

test "zero sized struct in tuple handled correctly" {
    const State = struct {
        const Self = @This();
        data: @Type(.{
            .Struct = .{
                .is_tuple = true,
                .layout = .Auto,
                .decls = &.{},
                .fields = &.{.{
                    .name = "0",
                    .type = struct {},
                    .default_value = null,
                    .is_comptime = false,
                    .alignment = 0,
                }},
            },
        }),

        pub fn do(this: Self) usize {
            return @sizeOf(@TypeOf(this));
        }
    };

    var s: State = undefined;
    try expect(s.do() == 0);
}

test "tuple type with void field and a runtime field" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    const T = std.meta.Tuple(&[_]type{ usize, void });
    var t: T = .{ 5, {} };
    try expect(t[0] == 5);
}

test "branching inside tuple literal" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const S = struct {
        fn foo(a: anytype) !void {
            try expect(a[0] == 1234);
        }
    };
    var a = false;
    try S.foo(.{if (a) @as(u32, 5678) else @as(u32, 1234)});
}

test "tuple initialized with a runtime known value" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    const E = union(enum) { e: []const u8 };
    const W = union(enum) { w: E };
    var e = E{ .e = "test" };
    const w = .{W{ .w = e }};
    try expectEqualStrings(w[0].w.e, "test");
}

test "tuple of struct concatenation and coercion to array" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;

    const StructWithDefault = struct { value: f32 = 42 };
    const SomeStruct = struct { array: [4]StructWithDefault };

    const value1 = SomeStruct{ .array = .{StructWithDefault{}} ++ [_]StructWithDefault{.{}} ** 3 };
    const value2 = SomeStruct{ .array = .{.{}} ++ [_]StructWithDefault{.{}} ** 3 };

    try expectEqual(value1, value2);
}

test "nested runtime conditionals in tuple initializer" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    var data: u8 = 0;
    const x = .{
        if (data != 0) "" else switch (@truncate(u1, data)) {
            0 => "up",
            1 => "down",
        },
    };
    try expectEqualStrings("up", x[0]);
}
