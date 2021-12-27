const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;
const Tag = std.meta.Tag;

test "@tagName" {
    try expect(mem.eql(u8, testEnumTagNameBare(BareNumber.Three), "Three"));
    comptime try expect(mem.eql(u8, testEnumTagNameBare(BareNumber.Three), "Three"));
}

fn testEnumTagNameBare(n: anytype) []const u8 {
    return @tagName(n);
}

const BareNumber = enum { One, Two, Three };

test "@tagName non-exhaustive enum" {
    try expect(mem.eql(u8, testEnumTagNameBare(NonExhaustive.B), "B"));
    comptime try expect(mem.eql(u8, testEnumTagNameBare(NonExhaustive.B), "B"));
}
const NonExhaustive = enum(u8) { A, B, _ };

test "@tagName is null-terminated" {
    const S = struct {
        fn doTheTest(n: BareNumber) !void {
            try expect(@tagName(n)[3] == 0);
        }
    };
    try S.doTheTest(.Two);
    try comptime S.doTheTest(.Two);
}

test "tag name with assigned enum values" {
    const LocalFoo = enum(u8) {
        A = 1,
        B = 0,
    };
    var b = LocalFoo.B;
    try expect(mem.eql(u8, @tagName(b), "B"));
}

const Bar = enum { A, B, C, D };

test "enum literal casting to optional" {
    var bar: ?Bar = undefined;
    bar = .B;

    try expect(bar.? == Bar.B);
}

const A = enum(u3) { One, Two, Three, Four, One2, Two2, Three2, Four2 };
const B = enum(u3) { One3, Two3, Three3, Four3, One23, Two23, Three23, Four23 };
const C = enum(u2) { One4, Two4, Three4, Four4 };

const BitFieldOfEnums = packed struct {
    a: A,
    b: B,
    c: C,
};

const bit_field_1 = BitFieldOfEnums{
    .a = A.Two,
    .b = B.Three3,
    .c = C.Four4,
};

test "bit field access with enum fields" {
    var data = bit_field_1;
    try expect(getA(&data) == A.Two);
    try expect(getB(&data) == B.Three3);
    try expect(getC(&data) == C.Four4);
    comptime try expect(@sizeOf(BitFieldOfEnums) == 1);

    data.b = B.Four3;
    try expect(data.b == B.Four3);

    data.a = A.Three;
    try expect(data.a == A.Three);
    try expect(data.b == B.Four3);
}

fn getA(data: *const BitFieldOfEnums) A {
    return data.a;
}

fn getB(data: *const BitFieldOfEnums) B {
    return data.b;
}

fn getC(data: *const BitFieldOfEnums) C {
    return data.c;
}
