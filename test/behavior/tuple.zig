const builtin = @import("builtin");
const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "tuple concatenation" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var a: i32 = 1;
            var b: i32 = 2;
            var x = .{a};
            var y = .{b};
            var c = x ++ y;
            try expectEqual(@as(i32, 1), c[0]);
            try expectEqual(@as(i32, 2), c[1]);
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
                inline for (t) |x, i| try expect(x == 1 + i % 3);
            }
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "more tuple concatenation" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend != .stage1) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend != .stage1) return error.SkipZigTest; // TODO

    const T = @Type(.{
        .Struct = .{
            .is_tuple = true,
            .layout = .Auto,
            .decls = &.{},
            .fields = &.{
                .{
                    .name = "0",
                    .field_type = i32,
                    .default_value = null,
                    .is_comptime = false,
                    .alignment = @alignOf(i32),
                },
                .{
                    .name = "1",
                    .field_type = u8,
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
