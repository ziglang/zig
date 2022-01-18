const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;
const maxInt = std.math.maxInt;
const builtin = @import("builtin");

test "int to ptr cast" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    const x = @as(usize, 13);
    const y = @intToPtr(*u8, x);
    const z = @ptrToInt(y);
    try expect(z == 13);
}

test "integer literal to pointer cast" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    const vga_mem = @intToPtr(*u16, 0xB8000);
    try expect(@ptrToInt(vga_mem) == 0xB8000);
}

test "peer type resolution: ?T and T" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    try expect(peerTypeTAndOptionalT(true, false).? == 0);
    try expect(peerTypeTAndOptionalT(false, false).? == 3);
    comptime {
        try expect(peerTypeTAndOptionalT(true, false).? == 0);
        try expect(peerTypeTAndOptionalT(false, false).? == 3);
    }
}
fn peerTypeTAndOptionalT(c: bool, b: bool) ?usize {
    if (c) {
        return if (b) null else @as(usize, 0);
    }

    return @as(usize, 3);
}

test "resolve undefined with integer" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    try testResolveUndefWithInt(true, 1234);
    comptime try testResolveUndefWithInt(true, 1234);
}
fn testResolveUndefWithInt(b: bool, x: i32) !void {
    const value = if (b) x else undefined;
    if (b) {
        try expect(value == x);
    }
}

test "@intCast to comptime_int" {
    try expect(@intCast(comptime_int, 0) == 0);
}

test "implicit cast comptime numbers to any type when the value fits" {
    const a: u64 = 255;
    var b: u8 = a;
    try expect(b == 255);
}

test "implicit cast comptime_int to comptime_float" {
    comptime try expect(@as(comptime_float, 10) == @as(f32, 10));
    try expect(2 == 2.0);
}

test "comptime_int @intToFloat" {
    {
        const result = @intToFloat(f16, 1234);
        try expect(@TypeOf(result) == f16);
        try expect(result == 1234.0);
    }
    {
        const result = @intToFloat(f32, 1234);
        try expect(@TypeOf(result) == f32);
        try expect(result == 1234.0);
    }
    {
        const result = @intToFloat(f64, 1234);
        try expect(@TypeOf(result) == f64);
        try expect(result == 1234.0);
    }
    {
        const result = @intToFloat(f128, 1234);
        try expect(@TypeOf(result) == f128);
        try expect(result == 1234.0);
    }
    // big comptime_int (> 64 bits) to f128 conversion
    {
        const result = @intToFloat(f128, 0x1_0000_0000_0000_0000);
        try expect(@TypeOf(result) == f128);
        try expect(result == 0x1_0000_0000_0000_0000.0);
    }
}

test "@floatToInt" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    try testFloatToInts();
    comptime try testFloatToInts();
}

fn testFloatToInts() !void {
    const x = @as(i32, 1e4);
    try expect(x == 10000);
    const y = @floatToInt(i32, @as(f32, 1e4));
    try expect(y == 10000);
    try expectFloatToInt(f32, 255.1, u8, 255);
    try expectFloatToInt(f32, 127.2, i8, 127);
    try expectFloatToInt(f32, -128.2, i8, -128);
}

fn expectFloatToInt(comptime F: type, f: F, comptime I: type, i: I) !void {
    try expect(@floatToInt(I, f) == i);
}

test "implicitly cast indirect pointer to maybe-indirect pointer" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const S = struct {
        const Self = @This();
        x: u8,
        fn constConst(p: *const *const Self) u8 {
            return p.*.x;
        }
        fn maybeConstConst(p: ?*const *const Self) u8 {
            return p.?.*.x;
        }
        fn constConstConst(p: *const *const *const Self) u8 {
            return p.*.*.x;
        }
        fn maybeConstConstConst(p: ?*const *const *const Self) u8 {
            return p.?.*.*.x;
        }
    };
    const s = S{ .x = 42 };
    const p = &s;
    const q = &p;
    const r = &q;
    try expect(42 == S.constConst(q));
    try expect(42 == S.maybeConstConst(q));
    try expect(42 == S.constConstConst(r));
    try expect(42 == S.maybeConstConstConst(r));
}

test "@intCast comptime_int" {
    const result = @intCast(i32, 1234);
    try expect(@TypeOf(result) == i32);
    try expect(result == 1234);
}

test "@floatCast comptime_int and comptime_float" {
    {
        const result = @floatCast(f16, 1234);
        try expect(@TypeOf(result) == f16);
        try expect(result == 1234.0);
    }
    {
        const result = @floatCast(f16, 1234.0);
        try expect(@TypeOf(result) == f16);
        try expect(result == 1234.0);
    }
    {
        const result = @floatCast(f32, 1234);
        try expect(@TypeOf(result) == f32);
        try expect(result == 1234.0);
    }
    {
        const result = @floatCast(f32, 1234.0);
        try expect(@TypeOf(result) == f32);
        try expect(result == 1234.0);
    }
}

test "coerce undefined to optional" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    try expect(MakeType(void).getNull() == null);
    try expect(MakeType(void).getNonNull() != null);
}

fn MakeType(comptime T: type) type {
    return struct {
        fn getNull() ?T {
            return null;
        }

        fn getNonNull() ?T {
            return @as(T, undefined);
        }
    };
}

test "implicit cast from *[N]T to [*c]T" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    var x: [4]u16 = [4]u16{ 0, 1, 2, 3 };
    var y: [*c]u16 = &x;

    try expect(std.mem.eql(u16, x[0..4], y[0..4]));
    x[0] = 8;
    y[3] = 6;
    try expect(std.mem.eql(u16, x[0..4], y[0..4]));
}

test "*usize to *void" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    var i = @as(usize, 0);
    var v = @ptrCast(*void, &i);
    v.* = {};
}

test "@intToEnum passed a comptime_int to an enum with one item" {
    const E = enum { A };
    const x = @intToEnum(E, 0);
    try expect(x == E.A);
}

test "@intCast to u0 and use the result" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const S = struct {
        fn doTheTest(zero: u1, one: u1, bigzero: i32) !void {
            try expect((one << @intCast(u0, bigzero)) == 1);
            try expect((zero << @intCast(u0, bigzero)) == 0);
        }
    };
    try S.doTheTest(0, 1, 0);
    comptime try S.doTheTest(0, 1, 0);
}

test "peer result null and comptime_int" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const S = struct {
        fn blah(n: i32) ?i32 {
            if (n == 0) {
                return null;
            } else if (n < 0) {
                return -1;
            } else {
                return 1;
            }
        }
    };

    try expect(S.blah(0) == null);
    comptime try expect(S.blah(0) == null);
    try expect(S.blah(10).? == 1);
    comptime try expect(S.blah(10).? == 1);
    try expect(S.blah(-10).? == -1);
    comptime try expect(S.blah(-10).? == -1);
}

test "*const ?[*]const T to [*c]const [*c]const T" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    var array = [_]u8{ 'o', 'k' };
    const opt_array_ptr: ?[*]const u8 = &array;
    const a: *const ?[*]const u8 = &opt_array_ptr;
    const b: [*c]const [*c]const u8 = a;
    try expect(b.*[0] == 'o');
    try expect(b[0][1] == 'k');
}

test "array coersion to undefined at runtime" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    @setRuntimeSafety(true);

    // TODO implement @setRuntimeSafety in stage2
    if (builtin.zig_backend != .stage1 and builtin.mode != .Debug and builtin.mode != .ReleaseSafe) {
        return error.SkipZigTest;
    }

    var array = [4]u8{ 3, 4, 5, 6 };
    var undefined_val = [4]u8{ 0xAA, 0xAA, 0xAA, 0xAA };

    try expect(std.mem.eql(u8, &array, &array));
    array = undefined;
    try expect(std.mem.eql(u8, &array, &undefined_val));
}

test "implicitly cast from int to anyerror!?T" {
    implicitIntLitToOptional();
    comptime implicitIntLitToOptional();
}
fn implicitIntLitToOptional() void {
    const f: ?i32 = 1;
    _ = f;
    const g: anyerror!?i32 = 1;
    _ = g catch {};
}

test "return u8 coercing into ?u32 return type" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            try expect(foo(123).? == 123);
        }
        fn foo(arg: u8) ?u32 {
            return arg;
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "cast from ?[*]T to ??[*]T" {
    const a: ??[*]u8 = @as(?[*]u8, null);
    try expect(a != null and a.? == null);
}

test "peer type unsigned int to signed" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    var w: u31 = 5;
    var x: u8 = 7;
    var y: i32 = -5;
    var a = w + y + x;
    comptime try expect(@TypeOf(a) == i32);
    try expect(a == 7);
}
