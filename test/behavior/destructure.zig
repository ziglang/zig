const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const expect = std.testing.expect;

test "simple destructure" {
    const S = struct {
        fn doTheTest() !void {
            var x: u32 = undefined;
            x, const y, var z: u64 = .{ 1, @as(u16, 2), 3 };
            _ = &z;

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
        fn doTheTest() !void {
            {
                comptime var x: f32 = undefined;
                comptime x, const y, var z = .{ 0.5, 123, 456 }; // z is a comptime var
                _ = &z;

                comptime assert(@TypeOf(y) == comptime_int);
                comptime assert(@TypeOf(z) == comptime_int);
                comptime assert(x == 0.5);
                comptime assert(y == 123);
                comptime assert(z == 456);
            }
            {
                var w: u8, var x: u8 = .{ 1, 2 };
                w, var y: u8 = .{ 3, 4 };
                var z: u8, x = .{ 5, 6 };
                y, z = .{ 7, 8 };
                {
                    w += 1;
                    x -= 2;
                    y *= 3;
                    z /= 4;
                }
                try expect(w == 4);
                try expect(x == 4);
                try expect(y == 21);
                try expect(z == 2);
            }
            {
                comptime var w, var x = .{ 1, 2 };
                comptime w, var y = .{ 3, 4 };
                comptime var z, x = .{ 5, 6 };
                comptime y, z = .{ 7, 8 };
                comptime {
                    w += 1;
                    x -= 2;
                    y *= 3;
                    z /= 4;
                }
                comptime assert(w == 4);
                comptime assert(x == 4);
                comptime assert(y == 21);
                comptime assert(z == 2);
            }
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
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

test "destructure of comptime-known tuple is comptime-known" {
    const x, const y = .{ 1, 2 };

    comptime assert(@TypeOf(x) == comptime_int);
    comptime assert(x == 1);

    comptime assert(@TypeOf(y) == comptime_int);
    comptime assert(y == 2);
}

test "destructure of comptime-known tuple where some destinations are runtime-known is comptime-known" {
    var z: u32 = undefined;
    var x: u8, const y, z = .{ 1, 2, 3 };
    _ = &x;

    comptime assert(@TypeOf(y) == comptime_int);
    comptime assert(y == 2);

    try expect(x == 1);
    try expect(z == 3);
}

test "destructure of tuple with comptime fields results in some comptime-known values" {
    var runtime: u32 = 42;
    _ = &runtime;
    const a, const b, const c, const d = .{ 123, runtime, 456, runtime };

    // a, c are comptime-known
    // b, d are runtime-known

    comptime assert(@TypeOf(a) == comptime_int);
    comptime assert(@TypeOf(b) == u32);
    comptime assert(@TypeOf(c) == comptime_int);
    comptime assert(@TypeOf(d) == u32);

    comptime assert(a == 123);
    comptime assert(c == 456);

    try expect(b == 42);
    try expect(d == 42);
}

test "destructure vector" {
    const vec: @Vector(2, i32) = .{ 1, 2 };
    const x, const y = vec;

    comptime assert(@TypeOf(x) == i32);
    comptime assert(@TypeOf(y) == i32);

    try expect(x == 1);
    try expect(y == 2);
}
