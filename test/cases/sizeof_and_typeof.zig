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

test "offsetOf" {
    // Packed structs have fixed memory layout
    const p: P = undefined;
    assert(@offsetOf(P, "a") == 0);
    assert(@offsetOf(@typeOf(p), "b") == 1);
    assert(@offsetOf(@typeOf(p), "c") == 5);

    // Non-packed struct fields can be moved/padded
    const a: A = undefined;
    assert(usize(&a.a) - usize(&a) == @offsetOf(A, "a"));
    assert(usize(&a.b) - usize(&a) == @offsetOf(@typeOf(a), "b"));
    assert(usize(&a.c) - usize(&a) == @offsetOf(@typeOf(a), "c"));
}