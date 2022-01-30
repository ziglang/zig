const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "tuple concatenation" {
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            {
                const t = .{} ** 4;
                try expectEqual(0, @typeInfo(@TypeOf(t)).Struct.fields.len);
            }
            {
                const t = .{'a'} ** 4;
                try expectEqual(4, @typeInfo(@TypeOf(t)).Struct.fields.len);
                inline for (t) |x| try expectEqual('a', x);
            }
            {
                const t = .{ 1, 2, 3 } ** 4;
                try expectEqual(12, @typeInfo(@TypeOf(t)).Struct.fields.len);
                inline for (t) |x, i| try expectEqual(1 + i % 3, x);
            }
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "more tuple concatenation" {
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;

    const S = struct {
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

    try S.doTheTest();
    comptime try S.doTheTest();
}

test "pass tuple to comptime var parameter" {
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;

    const T = @Type(std.builtin.TypeInfo{
        .Struct = std.builtin.TypeInfo.Struct{
            .is_tuple = true,
            .layout = .Auto,
            .decls = &[_]std.builtin.TypeInfo.Declaration{},
            .fields = &[_]std.builtin.TypeInfo.StructField{
                .{
                    .name = "0",
                    .field_type = i32,
                    .default_value = @as(?i32, null),
                    .is_comptime = false,
                    .alignment = @alignOf(i32),
                },
                .{
                    .name = "1",
                    .field_type = u8,
                    .default_value = @as(?i32, null),
                    .is_comptime = false,
                    .alignment = @alignOf(i32),
                },
            },
        },
    });
    const S = struct {
        fn doTheTest() !void {
            var obj: T = .{ -1234, 128 };
            try testing.expectEqual(@as(i32, -1234), obj[0]);
            try testing.expectEqual(@as(u8, 128), obj[1]);
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
}
