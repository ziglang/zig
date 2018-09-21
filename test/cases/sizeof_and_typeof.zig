const assert = @import("std").debug.assert;

test "sizeofAndTypeOf" {
    const y: @typeOf(x) = 120;
    assert(@sizeOf(@typeOf(y)) == 2);
}
const x: u16 = 13;
const z: @typeOf(x) = 19;

const S = struct {
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

test "byteOffsetOf" {
    const p: P = undefined;
    std.debug.assert(@byteOffsetOf(P, "a") == 0 and @byteOffsetOf(S, "a") == 0);
    std.debug.assert(@byteOffsetOf(P, "b") == 1 and @byteOffsetOf(S, "b") == 4);
    std.debug.assert(@byteOffsetOf(P, "c") == 5 and @byteOffsetOf(S, "c") == 8);
    std.debug.assert(@byteOffsetOf(P, "d") == 6 and @byteOffsetOf(S, "d") == 9);
    std.debug.assert(@byteOffsetOf(P, "e") == 6 and @byteOffsetOf(S, "e") == 10);
    std.debug.assert(@byteOffsetOf(P, "f") == 7 and @byteOffsetOf(S, "f") == 12);
    std.debug.assert(@byteOffsetOf(P, "g") == 9 and @byteOffsetOf(S, "g") == 14);
}

test "bitOffsetOf" {
    const p: P = undefined;
    std.debug.assert(@bitOffsetOf(P, "a") == 0 and @bitOffsetOf(S, "a") == 0);
    std.debug.assert(@bitOffsetOf(P, "b") == 8 and @bitOffsetOf(S, "b") == 32);
    std.debug.assert(@bitOffsetOf(P, "c") == 40 and @bitOffsetOf(S, "c") == 64);
    std.debug.assert(@bitOffsetOf(P, "d") == 48 and @bitOffsetOf(S, "d") == 72);
    std.debug.assert(@bitOffsetOf(P, "e") == 51 and @bitOffsetOf(S, "e") == 80);
    std.debug.assert(@bitOffsetOf(P, "f") == 56 and @bitOffsetOf(S, "f") == 96);
    std.debug.assert(@bitOffsetOf(P, "g") == 72 and @bitOffsetOf(S, "g") == 112);
}