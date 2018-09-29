const builtin = @import("builtin");
const assert = @import("std").debug.assert;

test "@sizeOf and @typeOf" {
    const y: @typeOf(x) = 120;
    assert(@sizeOf(@typeOf(y)) == 2);
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
    assert(@byteOffsetOf(P, "a") == 0);
    assert(@byteOffsetOf(P, "b") == 1);
    assert(@byteOffsetOf(P, "c") == 5);
    assert(@byteOffsetOf(P, "d") == 6);
    assert(@byteOffsetOf(P, "e") == 6);
    assert(@byteOffsetOf(P, "f") == 7);
    assert(@byteOffsetOf(P, "g") == 9);

    // Normal struct fields can be moved/padded
    var a: A = undefined;
    assert(@ptrToInt(&a.a) - @ptrToInt(&a) == @byteOffsetOf(A, "a"));
    assert(@ptrToInt(&a.b) - @ptrToInt(&a) == @byteOffsetOf(A, "b"));
    assert(@ptrToInt(&a.c) - @ptrToInt(&a) == @byteOffsetOf(A, "c"));
    assert(@ptrToInt(&a.d) - @ptrToInt(&a) == @byteOffsetOf(A, "d"));
    assert(@ptrToInt(&a.e) - @ptrToInt(&a) == @byteOffsetOf(A, "e"));
    assert(@ptrToInt(&a.f) - @ptrToInt(&a) == @byteOffsetOf(A, "f"));
    assert(@ptrToInt(&a.g) - @ptrToInt(&a) == @byteOffsetOf(A, "g"));
}

test "@bitOffsetOf" {
    // Packed structs have fixed memory layout
    assert(@bitOffsetOf(P, "a") == 0);
    assert(@bitOffsetOf(P, "b") == 8);
    assert(@bitOffsetOf(P, "c") == 40);
    assert(@bitOffsetOf(P, "d") == 48);
    assert(@bitOffsetOf(P, "e") == 51);
    assert(@bitOffsetOf(P, "f") == 56);
    assert(@bitOffsetOf(P, "g") == 72);

    assert(@byteOffsetOf(A, "a") * 8 == @bitOffsetOf(A, "a"));
    assert(@byteOffsetOf(A, "b") * 8 == @bitOffsetOf(A, "b"));
    assert(@byteOffsetOf(A, "c") * 8 == @bitOffsetOf(A, "c"));
    assert(@byteOffsetOf(A, "d") * 8 == @bitOffsetOf(A, "d"));
    assert(@byteOffsetOf(A, "e") * 8 == @bitOffsetOf(A, "e"));
    assert(@byteOffsetOf(A, "f") * 8 == @bitOffsetOf(A, "f"));
    assert(@byteOffsetOf(A, "g") * 8 == @bitOffsetOf(A, "g"));
}
