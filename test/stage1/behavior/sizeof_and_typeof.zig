const builtin = @import("builtin");
const assertOrPanic = @import("std").debug.assertOrPanic;

test "@sizeOf and @typeOf" {
    const y: @typeOf(x) = 120;
    assertOrPanic(@sizeOf(@typeOf(y)) == 2);
    assertOrPanic(@sizeOf(u24) == 3);
}
const x: u16 = 13;
const z: @typeOf(x) = 19;

const A = struct {
    a: u8,
    b: u32,
    c: u8,
    d: u3,
    e: u5,
    f: u16,
    g: u16,
};

const P = packed struct {
    a: u8,
    b: u32,
    c: u8,
    d: u3,
    e: u5,
    f: u16,
    g: u16,
};

test "@byteOffsetOf" {
    // Packed structs have fixed memory layout
    assertOrPanic(@byteOffsetOf(P, "a") == 0);
    assertOrPanic(@byteOffsetOf(P, "b") == 1);
    assertOrPanic(@byteOffsetOf(P, "c") == 5);
    assertOrPanic(@byteOffsetOf(P, "d") == 6);
    assertOrPanic(@byteOffsetOf(P, "e") == 6);
    assertOrPanic(@byteOffsetOf(P, "f") == 7);
    assertOrPanic(@byteOffsetOf(P, "g") == 9);

    // Normal struct fields can be moved/padded
    var a: A = undefined;
    assertOrPanic(@ptrToInt(&a.a) - @ptrToInt(&a) == @byteOffsetOf(A, "a"));
    assertOrPanic(@ptrToInt(&a.b) - @ptrToInt(&a) == @byteOffsetOf(A, "b"));
    assertOrPanic(@ptrToInt(&a.c) - @ptrToInt(&a) == @byteOffsetOf(A, "c"));
    assertOrPanic(@ptrToInt(&a.d) - @ptrToInt(&a) == @byteOffsetOf(A, "d"));
    assertOrPanic(@ptrToInt(&a.e) - @ptrToInt(&a) == @byteOffsetOf(A, "e"));
    assertOrPanic(@ptrToInt(&a.f) - @ptrToInt(&a) == @byteOffsetOf(A, "f"));
    assertOrPanic(@ptrToInt(&a.g) - @ptrToInt(&a) == @byteOffsetOf(A, "g"));
}

test "@bitOffsetOf" {
    // Packed structs have fixed memory layout
    assertOrPanic(@bitOffsetOf(P, "a") == 0);
    assertOrPanic(@bitOffsetOf(P, "b") == 8);
    assertOrPanic(@bitOffsetOf(P, "c") == 40);
    assertOrPanic(@bitOffsetOf(P, "d") == 48);
    assertOrPanic(@bitOffsetOf(P, "e") == 51);
    assertOrPanic(@bitOffsetOf(P, "f") == 56);
    assertOrPanic(@bitOffsetOf(P, "g") == 72);

    assertOrPanic(@byteOffsetOf(A, "a") * 8 == @bitOffsetOf(A, "a"));
    assertOrPanic(@byteOffsetOf(A, "b") * 8 == @bitOffsetOf(A, "b"));
    assertOrPanic(@byteOffsetOf(A, "c") * 8 == @bitOffsetOf(A, "c"));
    assertOrPanic(@byteOffsetOf(A, "d") * 8 == @bitOffsetOf(A, "d"));
    assertOrPanic(@byteOffsetOf(A, "e") * 8 == @bitOffsetOf(A, "e"));
    assertOrPanic(@byteOffsetOf(A, "f") * 8 == @bitOffsetOf(A, "f"));
    assertOrPanic(@byteOffsetOf(A, "g") * 8 == @bitOffsetOf(A, "g"));
}
