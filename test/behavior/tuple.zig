const builtin = @import("builtin");
const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
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
            _ = .{ &a, &b };
            const x = .{a};
            const y = .{b};
            const c = x ++ y;
            try expect(@as(i32, 1) == c[0]);
            try expect(@as(i32, 2) == c[1]);
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "tuple multiplication" {
    const S = struct {
        fn doTheTest() !void {
            {
                const t = .{} ** 4;
                try expect(@typeInfo(@TypeOf(t)).@"struct".fields.len == 0);
            }
            {
                const t = .{'a'} ** 4;
                try expect(@typeInfo(@TypeOf(t)).@"struct".fields.len == 4);
                inline for (t) |x| try expect(x == 'a');
            }
            {
                const t = .{ 1, 2, 3 } ** 4;
                try expect(@typeInfo(@TypeOf(t)).@"struct".fields.len == 12);
                inline for (t, 0..) |x, i| try expect(x == 1 + i % 3);
            }
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "more tuple concatenation" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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
    try comptime T.doTheTest();
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
    try comptime S.doTheTest();
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
            _ = &tmp;
        }
    };

    S.doTheTest();
    comptime S.doTheTest();
}

test "array-like initializer for tuple types" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const T = @Type(.{
        .@"struct" = .{
            .is_tuple = true,
            .layout = .auto,
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
            _ = &obj;
            try expect(@as(i32, -1234) == obj[0]);
            try expect(@as(u8, 128) == obj[1]);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "anon struct as the result from a labeled block" {
    const S = struct {
        fn doTheTest() !void {
            const precomputed = comptime blk: {
                var x: i32 = 1234;
                _ = &x;
                break :blk .{
                    .x = x,
                };
            };
            try expect(precomputed.x == 1234);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "tuple as the result from a labeled block" {
    const S = struct {
        fn doTheTest() !void {
            const precomputed = comptime blk: {
                var x: i32 = 1234;
                _ = &x;
                break :blk .{x};
            };
            try expect(precomputed[0] == 1234);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "initializing tuple with explicit type" {
    const T = @TypeOf(.{ @as(i32, 0), @as(u32, 0) });
    var a = T{ 0, 0 };
    _ = &a;
}

test "initializing anon struct with explicit type" {
    const T = @TypeOf(.{ .foo = @as(i32, 1), .bar = @as(i32, 2) });
    var a = T{ .foo = 1, .bar = 2 };
    _ = &a;
}

test "fieldParentPtr of tuple" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var x: u32 = 0;
    _ = &x;
    const tuple = .{ x, x };
    try testing.expect(&tuple == @as(@TypeOf(&tuple), @fieldParentPtr("1", &tuple[1])));
}

test "fieldParentPtr of anon struct" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var x: u32 = 0;
    _ = &x;
    const anon_st = .{ .foo = x, .bar = x };
    try testing.expect(&anon_st == @as(@TypeOf(&anon_st), @fieldParentPtr("bar", &anon_st.bar)));
}

test "offsetOf tuple" {
    var x: u32 = 0;
    _ = &x;
    const T = @TypeOf(.{ x, x });
    try expect(@offsetOf(T, "1") == @sizeOf(u32));
}

test "offsetOf anon struct" {
    var x: u32 = 0;
    _ = &x;
    const T = @TypeOf(.{ .foo = x, .bar = x });
    try expect(@offsetOf(T, "bar") == @sizeOf(u32));
}

test "initializing tuple with mixed comptime-runtime fields" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var x: u32 = 15;
    _ = &x;
    const T = @TypeOf(.{ @as(i32, -1234), @as(u32, 5678), x });
    var a: T = .{ -1234, 5678, x + 1 };
    _ = &a;
    try expect(a[2] == 16);
}

test "initializing anon struct with mixed comptime-runtime fields" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var x: u32 = 15;
    _ = &x;
    const T = @TypeOf(.{ .foo = @as(i32, -1234), .bar = x });
    var a: T = .{ .foo = -1234, .bar = x + 1 };
    _ = &a;
    try expect(a.bar == 16);
}

test "tuple in tuple passed to generic function" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const T = std.meta.Tuple(&[_]type{void});
    const x = T{{}};
    try expect(@TypeOf(x[0]) == void);
}

test "zero sized struct in tuple handled correctly" {
    const State = struct {
        const Self = @This();
        data: @Type(.{
            .@"struct" = .{
                .is_tuple = true,
                .layout = .auto,
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

    const T = std.meta.Tuple(&[_]type{ usize, void });
    var t: T = .{ 5, {} };
    _ = &t;
    try expect(t[0] == 5);
}

test "branching inside tuple literal" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn foo(a: anytype) !void {
            try expect(a[0] == 1234);
        }
    };
    var a = false;
    _ = &a;
    try S.foo(.{if (a) @as(u32, 5678) else @as(u32, 1234)});
}

test "tuple initialized with a runtime known value" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const E = union(enum) { e: []const u8 };
    const W = union(enum) { w: E };
    var e = E{ .e = "test" };
    _ = &e;
    const w = .{W{ .w = e }};
    try expectEqualStrings(w[0].w.e, "test");
}

test "tuple of struct concatenation and coercion to array" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const StructWithDefault = struct { value: f32 = 42 };
    const SomeStruct = struct { array: [4]StructWithDefault };

    const value1 = SomeStruct{ .array = .{StructWithDefault{}} ++ [_]StructWithDefault{.{}} ** 3 };
    const value2 = SomeStruct{ .array = .{.{}} ++ [_]StructWithDefault{.{}} ** 3 };

    try expectEqual(value1, value2);
}

test "nested runtime conditionals in tuple initializer" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var data: u8 = 0;
    _ = &data;
    const x = .{
        if (data != 0) "" else switch (@as(u1, @truncate(data))) {
            0 => "up",
            1 => "down",
        },
    };
    try expectEqualStrings("up", x[0]);
}

test "sentinel slice in tuple with other fields" {
    const S = struct {
        a: u32,
        b: u32,
    };

    const Submission = union(enum) {
        open: struct { *S, [:0]const u8, u32 },
    };

    _ = Submission;
}

test "sentinel slice in tuple" {
    const S = struct { [:0]const u8 };

    _ = S;
}

test "tuple pointer is indexable" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct { u32, bool };

    const x: S = .{ 123, true };
    comptime assert(@TypeOf(&(&x)[0]) == *const u32); // validate constness
    try expectEqual(@as(u32, 123), (&x)[0]);
    try expectEqual(true, (&x)[1]);

    var y: S = .{ 123, true };
    comptime assert(@TypeOf(&(&y)[0]) == *u32); // validate constness
    try expectEqual(@as(u32, 123), (&y)[0]);
    try expectEqual(true, (&y)[1]);

    (&y)[0] = 100;
    (&y)[1] = false;
    try expectEqual(@as(u32, 100), (&y)[0]);
    try expectEqual(false, (&y)[1]);
}

test "coerce anon tuple to tuple" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var x: u8 = 1;
    var y: u16 = 2;
    _ = .{ &x, &y };
    const t = .{ x, y };
    const s: struct { u8, u16 } = t;
    try expectEqual(x, s[0]);
    try expectEqual(y, s[1]);
}

test "empty tuple type" {
    const S = @Type(.{ .@"struct" = .{
        .layout = .auto,
        .fields = &.{},
        .decls = &.{},
        .is_tuple = true,
    } });

    const s: S = .{};
    try expect(s.len == 0);
}

test "tuple with comptime fields with non empty initializer" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const a: struct { comptime comptime_int = 0 } = .{0};
    _ = a;
}

test "tuple with runtime value coerced into a slice with a sentinel" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn f(a: [:null]const ?u8) !void {
            try expect(a[0] == 42);
        }
    };

    const c: u8 = 42;
    try S.f(&[_:null]?u8{c});
    try S.f(&.{c});

    var v: u8 = 42;
    _ = &v;
    try S.f(&[_:null]?u8{v});
    try S.f(&.{v});
}

test "tuple implicitly coerced to optional/error union struct/union" {
    const SomeUnion = union(enum) {
        variant: u8,
    };
    const SomeStruct = struct {
        struct_field: u8,
    };
    const OptEnum = struct {
        opt_union: ?SomeUnion,
    };
    const ErrEnum = struct {
        err_union: anyerror!SomeUnion,
    };
    const OptStruct = struct {
        opt_struct: ?SomeStruct,
    };
    const ErrStruct = struct {
        err_struct: anyerror!SomeStruct,
    };

    try expect((OptEnum{
        .opt_union = .{
            .variant = 1,
        },
    }).opt_union.?.variant == 1);

    try expect(((ErrEnum{
        .err_union = .{
            .variant = 1,
        },
    }).err_union catch unreachable).variant == 1);

    try expect((OptStruct{
        .opt_struct = .{
            .struct_field = 1,
        },
    }).opt_struct.?.struct_field == 1);

    try expect(((ErrStruct{
        .err_struct = .{
            .struct_field = 1,
        },
    }).err_struct catch unreachable).struct_field == 1);
}

test "comptime fields in tuple can be initialized" {
    const T = @TypeOf(.{ @as(i32, 0), @as(u32, 0) });
    var a: T = .{ 0, 0 };
    _ = &a;
}

test "tuple default values" {
    const T = struct {
        usize,
        usize = 123,
        usize = 456,
    };

    const t: T = .{1};

    try expectEqual(1, t[0]);
    try expectEqual(123, t[1]);
    try expectEqual(456, t[2]);
}
