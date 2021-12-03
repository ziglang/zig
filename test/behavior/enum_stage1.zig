const expect = @import("std").testing.expect;
const mem = @import("std").mem;
const Tag = @import("std").meta.Tag;

test "non-exhaustive enum" {
    const S = struct {
        const E = enum(u8) {
            a,
            b,
            _,
        };
        fn doTheTest(y: u8) !void {
            var e: E = .b;
            try expect(switch (e) {
                .a => false,
                .b => true,
                _ => false,
            });
            e = @intToEnum(E, 12);
            try expect(switch (e) {
                .a => false,
                .b => false,
                _ => true,
            });

            try expect(switch (e) {
                .a => false,
                .b => false,
                else => true,
            });
            e = .b;
            try expect(switch (e) {
                .a => false,
                else => true,
            });

            try expect(@typeInfo(E).Enum.fields.len == 2);
            e = @intToEnum(E, 12);
            try expect(@enumToInt(e) == 12);
            e = @intToEnum(E, y);
            try expect(@enumToInt(e) == 52);
            try expect(@typeInfo(E).Enum.is_exhaustive == false);
        }
    };
    try S.doTheTest(52);
    comptime try S.doTheTest(52);
}

test "empty non-exhaustive enum" {
    const S = struct {
        const E = enum(u8) {
            _,
        };
        fn doTheTest(y: u8) !void {
            var e = @intToEnum(E, y);
            try expect(switch (e) {
                _ => true,
            });
            try expect(@enumToInt(e) == y);

            try expect(@typeInfo(E).Enum.fields.len == 0);
            try expect(@typeInfo(E).Enum.is_exhaustive == false);
        }
    };
    try S.doTheTest(42);
    comptime try S.doTheTest(42);
}

test "single field non-exhaustive enum" {
    const S = struct {
        const E = enum(u8) { a, _ };
        fn doTheTest(y: u8) !void {
            var e: E = .a;
            try expect(switch (e) {
                .a => true,
                _ => false,
            });
            e = @intToEnum(E, 12);
            try expect(switch (e) {
                .a => false,
                _ => true,
            });

            try expect(switch (e) {
                .a => false,
                else => true,
            });
            e = .a;
            try expect(switch (e) {
                .a => true,
                else => false,
            });

            try expect(@enumToInt(@intToEnum(E, y)) == y);
            try expect(@typeInfo(E).Enum.fields.len == 1);
            try expect(@typeInfo(E).Enum.is_exhaustive == false);
        }
    };
    try S.doTheTest(23);
    comptime try S.doTheTest(23);
}

const Bar = enum { A, B, C, D };

const Number = enum { Zero, One, Two, Three, Four };

test "@tagName" {
    try expect(mem.eql(u8, testEnumTagNameBare(BareNumber.Three), "Three"));
    comptime try expect(mem.eql(u8, testEnumTagNameBare(BareNumber.Three), "Three"));
}

test "@tagName non-exhaustive enum" {
    try expect(mem.eql(u8, testEnumTagNameBare(NonExhaustive.B), "B"));
    comptime try expect(mem.eql(u8, testEnumTagNameBare(NonExhaustive.B), "B"));
}

test "@tagName is null-terminated" {
    const S = struct {
        fn doTheTest(n: BareNumber) !void {
            try expect(@tagName(n)[3] == 0);
        }
    };
    try S.doTheTest(.Two);
    try comptime S.doTheTest(.Two);
}

fn testEnumTagNameBare(n: anytype) []const u8 {
    return @tagName(n);
}

const BareNumber = enum { One, Two, Three };
const NonExhaustive = enum(u8) { A, B, _ };
const Small2 = enum(u2) { One, Two };
const Small = enum(u2) { One, Two, Three, Four };

test "set enum tag type" {
    {
        var x = Small.One;
        x = Small.Two;
        comptime try expect(Tag(Small) == u2);
    }
    {
        var x = Small2.One;
        x = Small2.Two;
        comptime try expect(Tag(Small2) == u2);
    }
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

test "casting enum to its tag type" {
    try testCastEnumTag(Small2.Two);
    comptime try testCastEnumTag(Small2.Two);
}

fn testCastEnumTag(value: Small2) !void {
    try expect(@enumToInt(value) == 1);
}

const MultipleChoice2 = enum(u32) {
    Unspecified1,
    A = 20,
    Unspecified2,
    B = 40,
    Unspecified3,
    C = 60,
    Unspecified4,
    D = 1000,
    Unspecified5,
};

test "enum with specified and unspecified tag values" {
    try testEnumWithSpecifiedAndUnspecifiedTagValues(MultipleChoice2.D);
    comptime try testEnumWithSpecifiedAndUnspecifiedTagValues(MultipleChoice2.D);
}

fn testEnumWithSpecifiedAndUnspecifiedTagValues(x: MultipleChoice2) !void {
    try expect(@enumToInt(x) == 1000);
    try expect(1234 == switch (x) {
        MultipleChoice2.A => 1,
        MultipleChoice2.B => 2,
        MultipleChoice2.C => 3,
        MultipleChoice2.D => @as(u32, 1234),
        MultipleChoice2.Unspecified1 => 5,
        MultipleChoice2.Unspecified2 => 6,
        MultipleChoice2.Unspecified3 => 7,
        MultipleChoice2.Unspecified4 => 8,
        MultipleChoice2.Unspecified5 => 9,
    });
}

test "cast integer literal to enum" {
    try expect(@intToEnum(MultipleChoice2, 0) == MultipleChoice2.Unspecified1);
    try expect(@intToEnum(MultipleChoice2, 40) == MultipleChoice2.B);
}

const EnumWithOneMember = enum { Eof };

fn doALoopThing(id: EnumWithOneMember) void {
    while (true) {
        if (id == EnumWithOneMember.Eof) {
            break;
        }
        @compileError("above if condition should be comptime");
    }
}

test "comparison operator on enum with one member is comptime known" {
    doALoopThing(EnumWithOneMember.Eof);
}

const State = enum { Start };
test "switch on enum with one member is comptime known" {
    var state = State.Start;
    switch (state) {
        State.Start => return,
    }
    @compileError("analysis should not reach here");
}

const EnumWithTagValues = enum(u4) {
    A = 1 << 0,
    B = 1 << 1,
    C = 1 << 2,
    D = 1 << 3,
};
test "enum with tag values don't require parens" {
    try expect(@enumToInt(EnumWithTagValues.C) == 0b0100);
}

test "enum with 1 field but explicit tag type should still have the tag type" {
    const Enum = enum(u8) {
        B = 2,
    };
    comptime try expect(@sizeOf(Enum) == @sizeOf(u8));
}

test "tag name with assigned enum values" {
    const LocalFoo = enum(u8) {
        A = 1,
        B = 0,
    };
    var b = LocalFoo.B;
    try expect(mem.eql(u8, @tagName(b), "B"));
}

test "enum literal in array literal" {
    const Items = enum { one, two };
    const array = [_]Items{ .one, .two };

    try expect(array[0] == .one);
    try expect(array[1] == .two);
}

test "signed integer as enum tag" {
    const SignedEnum = enum(i2) {
        A0 = -1,
        A1 = 0,
        A2 = 1,
    };

    try expect(@enumToInt(SignedEnum.A0) == -1);
    try expect(@enumToInt(SignedEnum.A1) == 0);
    try expect(@enumToInt(SignedEnum.A2) == 1);
}

test "enum value allocation" {
    const LargeEnum = enum(u32) {
        A0 = 0x80000000,
        A1,
        A2,
    };

    try expect(@enumToInt(LargeEnum.A0) == 0x80000000);
    try expect(@enumToInt(LargeEnum.A1) == 0x80000001);
    try expect(@enumToInt(LargeEnum.A2) == 0x80000002);
}

test "enum literal casting to tagged union" {
    const Arch = union(enum) {
        x86_64,
        arm: Arm32,

        const Arm32 = enum {
            v8_5a,
            v8_4a,
        };
    };

    var t = true;
    var x: Arch = .x86_64;
    var y = if (t) x else .x86_64;
    switch (y) {
        .x86_64 => {},
        else => @panic("fail"),
    }
}

test "enum with one member and custom tag type" {
    const E = enum(u2) {
        One,
    };
    try expect(@enumToInt(E.One) == 0);
    const E2 = enum(u2) {
        One = 2,
    };
    try expect(@enumToInt(E2.One) == 2);
}

test "enum literal casting to optional" {
    var bar: ?Bar = undefined;
    bar = .B;

    try expect(bar.? == Bar.B);
}

test "enum literal casting to error union with payload enum" {
    var bar: error{B}!Bar = undefined;
    bar = .B; // should never cast to the error set

    try expect((try bar) == Bar.B);
}

test "enum with one member and u1 tag type @enumToInt" {
    const Enum = enum(u1) {
        Test,
    };
    try expect(@enumToInt(Enum.Test) == 0);
}

test "enum with comptime_int tag type" {
    const Enum = enum(comptime_int) {
        One = 3,
        Two = 2,
        Three = 1,
    };
    comptime try expect(Tag(Enum) == comptime_int);
}

test "enum with one member default to u0 tag type" {
    const E0 = enum { X };
    comptime try expect(Tag(E0) == u0);
}

test "tagName on enum literals" {
    try expect(mem.eql(u8, @tagName(.FooBar), "FooBar"));
    comptime try expect(mem.eql(u8, @tagName(.FooBar), "FooBar"));
}

test "method call on an enum" {
    const S = struct {
        const E = enum {
            one,
            two,

            fn method(self: *E) bool {
                return self.* == .two;
            }

            fn generic_method(self: *E, foo: anytype) bool {
                return self.* == .two and foo == bool;
            }
        };
        fn doTheTest() !void {
            var e = E.two;
            try expect(e.method());
            try expect(e.generic_method(bool));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "exporting enum type and value" {
    const S = struct {
        const E = enum(c_int) { one, two };
        comptime {
            @export(E, .{ .name = "E" });
        }
        const e: E = .two;
        comptime {
            @export(e, .{ .name = "e" });
        }
    };
    try expect(S.e == .two);
}
