const assert = @import("std").debug.assert;

test "sizeofAndTypeOf" {
    const y: @typeOf(x) = 120;
    assert(@sizeOf(@typeOf(y)) == 2);
}
const x: u16 = 13;
const z: @typeOf(x) = 19;

const A = struct {
    a: u8,
    b: u32,
    c: u8,
};

const P = packed struct {
    a: u8,
    b: u32,
    c: u8,
};

test "byteOffsetOf" {
    // Packed structs have fixed memory layout
    const p: P = undefined;
    assert(@byteOffsetOf(P, "a") == 0);
    assert(@byteOffsetOf(@typeOf(p), "b") == 1);
    assert(@byteOffsetOf(@typeOf(p), "c") == 5);

    // Non-packed struct fields can be moved/padded
    const a: A = undefined;
    assert(@ptrToInt(&a.a) - @ptrToInt(&a) == @byteOffsetOf(A, "a"));
    assert(@ptrToInt(&a.b) - @ptrToInt(&a) == @byteOffsetOf(@typeOf(a), "b"));
    assert(@ptrToInt(&a.c) - @ptrToInt(&a) == @byteOffsetOf(@typeOf(a), "c"));
}