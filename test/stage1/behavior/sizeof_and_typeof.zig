const std = @import("std");
const builtin = std.builtin;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "@sizeOf and @TypeOf" {
    const y: @TypeOf(x) = 120;
    expect(@sizeOf(@TypeOf(y)) == 2);
}
const x: u16 = 13;
const z: @TypeOf(x) = 19;

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

test "@byteOffsetOf" {
    // Packed structs have fixed memory layout
    expect(@byteOffsetOf(P, "a") == 0);
    expect(@byteOffsetOf(P, "b") == 1);
    expect(@byteOffsetOf(P, "c") == 5);
    expect(@byteOffsetOf(P, "d") == 6);
    expect(@byteOffsetOf(P, "e") == 6);
    expect(@byteOffsetOf(P, "f") == 7);
    expect(@byteOffsetOf(P, "g") == 9);
    expect(@byteOffsetOf(P, "h") == 11);
    expect(@byteOffsetOf(P, "i") == 12);

    // Normal struct fields can be moved/padded
    var a: A = undefined;
    expect(@ptrToInt(&a.a) - @ptrToInt(&a) == @byteOffsetOf(A, "a"));
    expect(@ptrToInt(&a.b) - @ptrToInt(&a) == @byteOffsetOf(A, "b"));
    expect(@ptrToInt(&a.c) - @ptrToInt(&a) == @byteOffsetOf(A, "c"));
    expect(@ptrToInt(&a.d) - @ptrToInt(&a) == @byteOffsetOf(A, "d"));
    expect(@ptrToInt(&a.e) - @ptrToInt(&a) == @byteOffsetOf(A, "e"));
    expect(@ptrToInt(&a.f) - @ptrToInt(&a) == @byteOffsetOf(A, "f"));
    expect(@ptrToInt(&a.g) - @ptrToInt(&a) == @byteOffsetOf(A, "g"));
    expect(@ptrToInt(&a.h) - @ptrToInt(&a) == @byteOffsetOf(A, "h"));
    expect(@ptrToInt(&a.i) - @ptrToInt(&a) == @byteOffsetOf(A, "i"));
}

test "@byteOffsetOf packed struct, array length not power of 2 or multiple of native pointer width in bytes" {
    const p3a_len = 3;
    const P3 = packed struct {
        a: [p3a_len]u8,
        b: usize,
    };
    std.testing.expectEqual(0, @byteOffsetOf(P3, "a"));
    std.testing.expectEqual(p3a_len, @byteOffsetOf(P3, "b"));

    const p5a_len = 5;
    const P5 = packed struct {
        a: [p5a_len]u8,
        b: usize,
    };
    std.testing.expectEqual(0, @byteOffsetOf(P5, "a"));
    std.testing.expectEqual(p5a_len, @byteOffsetOf(P5, "b"));

    const p6a_len = 6;
    const P6 = packed struct {
        a: [p6a_len]u8,
        b: usize,
    };
    std.testing.expectEqual(0, @byteOffsetOf(P6, "a"));
    std.testing.expectEqual(p6a_len, @byteOffsetOf(P6, "b"));

    const p7a_len = 7;
    const P7 = packed struct {
        a: [p7a_len]u8,
        b: usize,
    };
    std.testing.expectEqual(0, @byteOffsetOf(P7, "a"));
    std.testing.expectEqual(p7a_len, @byteOffsetOf(P7, "b"));

    const p9a_len = 9;
    const P9 = packed struct {
        a: [p9a_len]u8,
        b: usize,
    };
    std.testing.expectEqual(0, @byteOffsetOf(P9, "a"));
    std.testing.expectEqual(p9a_len, @byteOffsetOf(P9, "b"));

    // 10, 11, 12, 13, 14, 15, 17, 18, 19, 20, 21, 22, 23, 25 etc. are further cases
}

test "@bitOffsetOf" {
    // Packed structs have fixed memory layout
    expect(@bitOffsetOf(P, "a") == 0);
    expect(@bitOffsetOf(P, "b") == 8);
    expect(@bitOffsetOf(P, "c") == 40);
    expect(@bitOffsetOf(P, "d") == 48);
    expect(@bitOffsetOf(P, "e") == 51);
    expect(@bitOffsetOf(P, "f") == 56);
    expect(@bitOffsetOf(P, "g") == 72);

    expect(@byteOffsetOf(A, "a") * 8 == @bitOffsetOf(A, "a"));
    expect(@byteOffsetOf(A, "b") * 8 == @bitOffsetOf(A, "b"));
    expect(@byteOffsetOf(A, "c") * 8 == @bitOffsetOf(A, "c"));
    expect(@byteOffsetOf(A, "d") * 8 == @bitOffsetOf(A, "d"));
    expect(@byteOffsetOf(A, "e") * 8 == @bitOffsetOf(A, "e"));
    expect(@byteOffsetOf(A, "f") * 8 == @bitOffsetOf(A, "f"));
    expect(@byteOffsetOf(A, "g") * 8 == @bitOffsetOf(A, "g"));
}

test "@sizeOf on compile-time types" {
    expect(@sizeOf(comptime_int) == 0);
    expect(@sizeOf(comptime_float) == 0);
    expect(@sizeOf(@TypeOf(.hi)) == 0);
    expect(@sizeOf(@TypeOf(type)) == 0);
}

test "@sizeOf(T) == 0 doesn't force resolving struct size" {
    const S = struct {
        const Foo = struct {
            y: if (@sizeOf(Foo) == 0) u64 else u32,
        };
        const Bar = struct {
            x: i32,
            y: if (0 == @sizeOf(Bar)) u64 else u32,
        };
    };

    expect(@sizeOf(S.Foo) == 4);
    expect(@sizeOf(S.Bar) == 8);
}

test "@TypeOf() has no runtime side effects" {
    const S = struct {
        fn foo(comptime T: type, ptr: *T) T {
            ptr.* += 1;
            return ptr.*;
        }
    };
    var data: i32 = 0;
    const T = @TypeOf(S.foo(i32, &data));
    comptime expect(T == i32);
    expect(data == 0);
}

test "@TypeOf() with multiple arguments" {
    {
        var var_1: u32 = undefined;
        var var_2: u8 = undefined;
        var var_3: u64 = undefined;
        comptime expect(@TypeOf(var_1, var_2, var_3) == u64);
    }
    {
        var var_1: f16 = undefined;
        var var_2: f32 = undefined;
        var var_3: f64 = undefined;
        comptime expect(@TypeOf(var_1, var_2, var_3) == f64);
    }
    {
        var var_1: u16 = undefined;
        comptime expect(@TypeOf(var_1, 0xffff) == u16);
    }
    {
        var var_1: f32 = undefined;
        comptime expect(@TypeOf(var_1, 3.1415) == f32);
    }
}

test "branching logic inside @TypeOf" {
    const S = struct {
        var data: i32 = 0;
        fn foo() anyerror!i32 {
            data += 1;
            return undefined;
        }
    };
    const T = @TypeOf(S.foo() catch undefined);
    comptime expect(T == i32);
    expect(S.data == 0);
}

fn fn1(alpha: bool) void {
    const n: usize = 7;
    const v = if (alpha) n else @sizeOf(usize);
}

test "lazy @sizeOf result is checked for definedness" {
    const f = fn1;
}

test "@bitSizeOf" {
    expect(@bitSizeOf(u2) == 2);
    expect(@bitSizeOf(u8) == @sizeOf(u8) * 8);
    expect(@bitSizeOf(struct {
        a: u2,
    }) == 8);
    expect(@bitSizeOf(packed struct {
        a: u2,
    }) == 2);
}

test "@sizeOf comparison against zero" {
    const S0 = struct {
        f: *@This(),
    };
    const U0 = union {
        f: *@This(),
    };
    const S1 = struct {
        fn H(comptime T: type) type {
            return struct {
                x: T,
            };
        }
        f0: H(*@This()),
        f1: H(**@This()),
        f2: H(***@This()),
    };
    const U1 = union {
        fn H(comptime T: type) type {
            return struct {
                x: T,
            };
        }
        f0: H(*@This()),
        f1: H(**@This()),
        f2: H(***@This()),
    };
    const S = struct {
        fn doTheTest(comptime T: type, comptime result: bool) void {
            expectEqual(result, @sizeOf(T) > 0);
        }
    };
    // Zero-sized type
    S.doTheTest(u0, false);
    S.doTheTest(*u0, false);
    // Non byte-sized type
    S.doTheTest(u1, true);
    S.doTheTest(*u1, true);
    // Regular type
    S.doTheTest(u8, true);
    S.doTheTest(*u8, true);
    S.doTheTest(f32, true);
    S.doTheTest(*f32, true);
    // Container with ptr pointing to themselves
    S.doTheTest(S0, true);
    S.doTheTest(U0, true);
    S.doTheTest(S1, true);
    S.doTheTest(U1, true);
}
