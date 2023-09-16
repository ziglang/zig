const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

test "simple destructure" {
    const S = struct {
        fn doTheTest() !void {
            var x: u32 = undefined;
            x, const y, var z: u64 = .{ 1, @as(u16, 2), 3 };

            comptime assert(@TypeOf(y) == u16);

            try expect(x == 1);
            try expect(y == 2);
            try expect(z == 3);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "destructure with comptime syntax" {
    const S = struct {
        fn doTheTest() void {
            comptime var x: f32 = undefined;
            comptime x, const y, var z = .{ 0.5, 123, 456 }; // z is a comptime var

            comptime assert(@TypeOf(y) == comptime_int);
            comptime assert(@TypeOf(z) == comptime_int);
            comptime assert(x == 0.5);
            comptime assert(y == 123);
            comptime assert(z == 456);
        }
    };

    S.doTheTest();
    comptime S.doTheTest();
}

test "destructure from labeled block" {
    const S = struct {
        fn doTheTest(rt_true: bool) !void {
            const x: u32, const y: u8, const z: i64 = blk: {
                if (rt_true) break :blk .{ 1, 2, 3 };
                break :blk .{ 4, 5, 6 };
            };

            try expect(x == 1);
            try expect(y == 2);
            try expect(z == 3);
        }
    };

    try S.doTheTest(true);
    try comptime S.doTheTest(true);
}

test "destructure tuple value" {
    const tup: struct { f32, u32, i64 } = .{ 10.0, 20, 30 };
    const x, const y, const z = tup;

    comptime assert(@TypeOf(x) == f32);
    comptime assert(@TypeOf(y) == u32);
    comptime assert(@TypeOf(z) == i64);

    try expect(x == 10.0);
    try expect(y == 20);
    try expect(z == 30);
}

test "destructure array value" {
    const arr: [3]u32 = .{ 10, 20, 30 };
    const x, const y, const z = arr;

    comptime assert(@TypeOf(x) == u32);
    comptime assert(@TypeOf(y) == u32);
    comptime assert(@TypeOf(z) == u32);

    try expect(x == 10);
    try expect(y == 20);
    try expect(z == 30);
}

test "destructure from struct init with named tuple fields" {
    const Tuple = struct { u8, u16, u32 };
    const x, const y, const z = Tuple{
        .@"0" = 100,
        .@"1" = 200,
        .@"2" = 300,
    };

    comptime assert(@TypeOf(x) == u8);
    comptime assert(@TypeOf(y) == u16);
    comptime assert(@TypeOf(z) == u32);

    try expect(x == 100);
    try expect(y == 200);
    try expect(z == 300);
}
