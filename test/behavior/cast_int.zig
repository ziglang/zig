const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const maxInt = std.math.maxInt;

test "@intCast i32 to u7" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var x: u128 = maxInt(u128);
    var y: i32 = 120;
    var z = x >> @as(u7, @intCast(y));
    try expect(z == 0xff);
}

test "coerce i8 to i32 and @intCast back" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var x: i8 = -5;
    var y: i32 = -5;
    try expect(y == x);

    var x2: i32 = -5;
    var y2: i8 = -5;
    try expect(y2 == @as(i8, @intCast(x2)));
}

test "coerce non byte-sized integers accross 32bits boundary" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    {
        var v: u21 = 6417;
        const a: u32 = v;
        const b: u64 = v;
        const c: u64 = a;
        var w: u64 = 0x1234567812345678;
        const d: u21 = @truncate(w);
        const e: u60 = d;
        try expectEqual(@as(u32, 6417), a);
        try expectEqual(@as(u64, 6417), b);
        try expectEqual(@as(u64, 6417), c);
        try expectEqual(@as(u21, 0x145678), d);
        try expectEqual(@as(u60, 0x145678), e);
    }

    {
        var v: u10 = 234;
        const a: u32 = v;
        const b: u64 = v;
        const c: u64 = a;
        var w: u64 = 0x1234567812345678;
        const d: u10 = @truncate(w);
        const e: u60 = d;
        try expectEqual(@as(u32, 234), a);
        try expectEqual(@as(u64, 234), b);
        try expectEqual(@as(u64, 234), c);
        try expectEqual(@as(u21, 0x278), d);
        try expectEqual(@as(u60, 0x278), e);
    }
    {
        var v: u7 = 11;
        const a: u32 = v;
        const b: u64 = v;
        const c: u64 = a;
        var w: u64 = 0x1234567812345678;
        const d: u7 = @truncate(w);
        const e: u60 = d;
        try expectEqual(@as(u32, 11), a);
        try expectEqual(@as(u64, 11), b);
        try expectEqual(@as(u64, 11), c);
        try expectEqual(@as(u21, 0x78), d);
        try expectEqual(@as(u60, 0x78), e);
    }

    {
        var v: i21 = -6417;
        const a: i32 = v;
        const b: i64 = v;
        const c: i64 = a;
        var w: i64 = -12345;
        const d: i21 = @intCast(w);
        const e: i60 = d;
        try expectEqual(@as(i32, -6417), a);
        try expectEqual(@as(i64, -6417), b);
        try expectEqual(@as(i64, -6417), c);
        try expectEqual(@as(i21, -12345), d);
        try expectEqual(@as(i60, -12345), e);
    }

    {
        var v: i10 = -234;
        const a: i32 = v;
        const b: i64 = v;
        const c: i64 = a;
        var w: i64 = -456;
        const d: i10 = @intCast(w);
        const e: i60 = d;
        try expectEqual(@as(i32, -234), a);
        try expectEqual(@as(i64, -234), b);
        try expectEqual(@as(i64, -234), c);
        try expectEqual(@as(i10, -456), d);
        try expectEqual(@as(i60, -456), e);
    }
    {
        var v: i7 = -11;
        const a: i32 = v;
        const b: i64 = v;
        const c: i64 = a;
        var w: i64 = -42;
        const d: i7 = @intCast(w);
        const e: i60 = d;
        try expectEqual(@as(i32, -11), a);
        try expectEqual(@as(i64, -11), b);
        try expectEqual(@as(i64, -11), c);
        try expectEqual(@as(i7, -42), d);
        try expectEqual(@as(i60, -42), e);
    }
}

