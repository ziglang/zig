const std = @import("std");
const expect = std.testing.expect;

test "@sizeOf and @TypeOf" {
    const y: @TypeOf(x) = 120;
    try expect(@sizeOf(@TypeOf(y)) == 2);
    try expect(@TypeOf(z) == u16);
}
const x: u16 = 13;
const z: @TypeOf(x) = 19;

test "@sizeOf on compile-time types" {
    try expect(@sizeOf(comptime_int) == 0);
    try expect(@sizeOf(comptime_float) == 0);
    try expect(@sizeOf(@TypeOf(.hi)) == 0);
    try expect(@sizeOf(@TypeOf(type)) == 0);
}

test "@TypeOf() with multiple arguments" {
    {
        var var_1: u32 = undefined;
        var var_2: u8 = undefined;
        var var_3: u64 = undefined;
        comptime try expect(@TypeOf(var_1, var_2, var_3) == u64);
    }
    {
        var var_1: f16 = undefined;
        var var_2: f32 = undefined;
        var var_3: f64 = undefined;
        comptime try expect(@TypeOf(var_1, var_2, var_3) == f64);
    }
    {
        var var_1: u16 = undefined;
        comptime try expect(@TypeOf(var_1, 0xffff) == u16);
    }
    {
        var var_1: f32 = undefined;
        comptime try expect(@TypeOf(var_1, 3.1415) == f32);
    }
}

fn fn1(alpha: bool) void {
    const n: usize = 7;
    _ = if (alpha) n else @sizeOf(usize);
}

test "lazy @sizeOf result is checked for definedness" {
    _ = fn1;
}

const A = struct {
    a: u8,
    b: u32,
    c: u8,
    d: u3,
    e: u5,
    f: u16,
    g: u16,
    h: u9,
    i: u7,
};

const P = packed struct {
    a: u8,
    b: u32,
    c: u8,
    d: u3,
    e: u5,
    f: u16,
    g: u16,
    h: u9,
    i: u7,
};

test "@offsetOf" {

    // Packed structs have fixed memory layout
    try expect(@offsetOf(P, "a") == 0);
    try expect(@offsetOf(P, "b") == 1);
    try expect(@offsetOf(P, "c") == 5);
    try expect(@offsetOf(P, "d") == 6);
    try expect(@offsetOf(P, "e") == 6);
    try expect(@offsetOf(P, "f") == 7);
    try expect(@offsetOf(P, "g") == 9);
    try expect(@offsetOf(P, "h") == 11);
    try expect(@offsetOf(P, "i") == 12);

    // // Normal struct fields can be moved/padded
    var a: A = undefined;
    try expect(@ptrToInt(&a.a) - @ptrToInt(&a) == @offsetOf(A, "a"));
    try expect(@ptrToInt(&a.b) - @ptrToInt(&a) == @offsetOf(A, "b"));
    try expect(@ptrToInt(&a.c) - @ptrToInt(&a) == @offsetOf(A, "c"));
    try expect(@ptrToInt(&a.d) - @ptrToInt(&a) == @offsetOf(A, "d"));
    try expect(@ptrToInt(&a.e) - @ptrToInt(&a) == @offsetOf(A, "e"));
    try expect(@ptrToInt(&a.f) - @ptrToInt(&a) == @offsetOf(A, "f"));
    try expect(@ptrToInt(&a.g) - @ptrToInt(&a) == @offsetOf(A, "g"));
    try expect(@ptrToInt(&a.h) - @ptrToInt(&a) == @offsetOf(A, "h"));
    try expect(@ptrToInt(&a.i) - @ptrToInt(&a) == @offsetOf(A, "i"));
}

test "@offsetOf packed struct, array length not power of 2 or multiple of native pointer width in bytes" {
    const p3a_len = 3;
    const P3 = packed struct {
        a: [p3a_len]u8,
        b: usize,
    };
    try std.testing.expect(0 == @offsetOf(P3, "a"));
    try std.testing.expect(p3a_len == @offsetOf(P3, "b"));

    const p5a_len = 5;
    const P5 = packed struct {
        a: [p5a_len]u8,
        b: usize,
    };
    try std.testing.expect(0 == @offsetOf(P5, "a"));
    try std.testing.expect(p5a_len == @offsetOf(P5, "b"));

    const p6a_len = 6;
    const P6 = packed struct {
        a: [p6a_len]u8,
        b: usize,
    };
    try std.testing.expect(0 == @offsetOf(P6, "a"));
    try std.testing.expect(p6a_len == @offsetOf(P6, "b"));

    const p7a_len = 7;
    const P7 = packed struct {
        a: [p7a_len]u8,
        b: usize,
    };
    try std.testing.expect(0 == @offsetOf(P7, "a"));
    try std.testing.expect(p7a_len == @offsetOf(P7, "b"));

    const p9a_len = 9;
    const P9 = packed struct {
        a: [p9a_len]u8,
        b: usize,
    };
    try std.testing.expect(0 == @offsetOf(P9, "a"));
    try std.testing.expect(p9a_len == @offsetOf(P9, "b"));

    // 10, 11, 12, 13, 14, 15, 17, 18, 19, 20, 21, 22, 23, 25 etc. are further cases
}

test "@bitOffsetOf" {
    // Packed structs have fixed memory layout
    try expect(@bitOffsetOf(P, "a") == 0);
    try expect(@bitOffsetOf(P, "b") == 8);
    try expect(@bitOffsetOf(P, "c") == 40);
    try expect(@bitOffsetOf(P, "d") == 48);
    try expect(@bitOffsetOf(P, "e") == 51);
    try expect(@bitOffsetOf(P, "f") == 56);
    try expect(@bitOffsetOf(P, "g") == 72);

    try expect(@offsetOf(A, "a") * 8 == @bitOffsetOf(A, "a"));
    try expect(@offsetOf(A, "b") * 8 == @bitOffsetOf(A, "b"));
    try expect(@offsetOf(A, "c") * 8 == @bitOffsetOf(A, "c"));
    try expect(@offsetOf(A, "d") * 8 == @bitOffsetOf(A, "d"));
    try expect(@offsetOf(A, "e") * 8 == @bitOffsetOf(A, "e"));
    try expect(@offsetOf(A, "f") * 8 == @bitOffsetOf(A, "f"));
    try expect(@offsetOf(A, "g") * 8 == @bitOffsetOf(A, "g"));
}
