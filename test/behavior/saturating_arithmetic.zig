const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const Vector = std.meta.Vector;

test "@addWithSaturation" {
    const S = struct {
        fn doTheTest() !void {
            const test_data = .{
                // { a, b, expected a+b }
                [_]i8{ -3, 10, 7 },
                [_]i8{ -128, -128, -128 },
                [_]i2{ 1, 1, 1 },
                [_]i64{ std.math.maxInt(i64), 1, std.math.maxInt(i64) },
                [_]i8{ 127, 127, 127 },
                [_]u8{ 3, 10, 13 },
                [_]u8{ 255, 255, 255 },
                [_]u2{ 3, 2, 3 },
                [_]u3{ 7, 1, 7 },
                [_]u128{ std.math.maxInt(u128), 1, std.math.maxInt(u128) },
            };

            inline for (test_data) |array| {
                const a = array[0];
                const b = array[1];
                const expected = array[2];
                const actual = @addWithSaturation(a, b);
                try expectEqual(expected, actual);
            }

            const u8x3 = std.meta.Vector(3, u8);
            try expectEqual(u8x3{ 255, 255, 255 }, @addWithSaturation(
                u8x3{ 255, 254, 1 },
                u8x3{ 1, 2, 255 },
            ));
            const i8x3 = std.meta.Vector(3, i8);
            try expectEqual(i8x3{ 127, 127, 127 }, @addWithSaturation(
                i8x3{ 127, 126, 1 },
                i8x3{ 1, 2, 127 },
            ));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "@subWithSaturation" {
    const S = struct {
        fn doTheTest() !void {
            const test_data = .{
                // { a, b, expected a-b }
                [_]i8{ -3, 10, -13 },
                [_]i8{ -128, -128, 0 },
                [_]i8{ -1, 127, -128 },
                [_]i64{ std.math.minInt(i64), 1, std.math.minInt(i64) },
                [_]i128{ std.math.minInt(i128), 1, std.math.minInt(i128) },
                [_]u8{ 10, 3, 7 },
                [_]u8{ 0, 255, 0 },
                [_]u5{ 0, 31, 0 },
                [_]u128{ 0, std.math.maxInt(u128), 0 },
            };

            inline for (test_data) |array| {
                const a = array[0];
                const b = array[1];
                const expected = array[2];
                const actual = @subWithSaturation(a, b);
                try expectEqual(expected, actual);
            }

            const u8x3 = std.meta.Vector(3, u8);
            try expectEqual(u8x3{ 0, 0, 0 }, @subWithSaturation(
                u8x3{ 0, 0, 0 },
                u8x3{ 255, 255, 255 },
            ));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "@mulWithSaturation" {
    const S = struct {
        fn doTheTest() !void {
            const test_data = .{
                // { a, b, expected a*b }
                [_]i8{ -3, 10, -30 },
                [_]i8{ -128, -128, 127 },
                [_]i8{ 2, 127, 127 },
                [_]i128{ std.math.maxInt(i128), std.math.maxInt(i128), std.math.maxInt(i128) },
                [_]u8{ 10, 3, 30 },
                [_]u8{ 2, 255, 255 },
                [_]u128{ std.math.maxInt(u128), std.math.maxInt(u128), std.math.maxInt(u128) },
            };

            inline for (test_data) |array| {
                const a = array[0];
                const b = array[1];
                const expected = array[2];
                const actual = @mulWithSaturation(a, b);
                try expectEqual(expected, actual);
            }

            const u8x3 = std.meta.Vector(3, u8);
            try expectEqual(u8x3{ 255, 255, 255 }, @mulWithSaturation(
                u8x3{ 2, 2, 2 },
                u8x3{ 255, 255, 255 },
            ));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "@shlWithSaturation" {
    const S = struct {
        fn doTheTest() !void {
            const test_data = .{
                // { a, b, expected a<<b }
                [_]i8{ 1, 2, 4 },
                [_]i8{ 127, 1, 127 },
                [_]i8{ -128, 1, -128 },
                [_]i128{ std.math.maxInt(i128), 64, std.math.maxInt(i128) },
                [_]u8{ 1, 2, 4 },
                [_]u8{ 255, 1, 255 },
                [_]u128{ std.math.maxInt(u128), 64, std.math.maxInt(u128) },
            };

            inline for (test_data) |array| {
                const a = array[0];
                const b = array[1];
                const expected = array[2];
                const actual = @shlWithSaturation(a, b);
                try expectEqual(expected, actual);
            }

            const u8x3 = std.meta.Vector(3, u8);
            try expectEqual(u8x3{ 255, 255, 255 }, @shlWithSaturation(
                u8x3{ 255, 255, 255 },
                u8x3{ 1, 1, 1 },
            ));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}
