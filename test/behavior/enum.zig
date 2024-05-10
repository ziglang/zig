const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;
const assert = std.debug.assert;
const mem = std.mem;
const Tag = std.meta.Tag;

const Number = enum { Zero, One, Two, Three, Four };

fn shouldEqual(n: Number, expected: u3) !void {
    try expect(@intFromEnum(n) == expected);
}

test "enum to int" {
    try shouldEqual(Number.Zero, 0);
    try shouldEqual(Number.One, 1);
    try shouldEqual(Number.Two, 2);
    try shouldEqual(Number.Three, 3);
    try shouldEqual(Number.Four, 4);
}

fn testIntToEnumEval(x: i32) !void {
    try expect(@as(IntToEnumNumber, @enumFromInt(x)) == IntToEnumNumber.Three);
}
const IntToEnumNumber = enum { Zero, One, Two, Three, Four };

test "int to enum" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testIntToEnumEval(3);
}

const ValueCount1 = enum {
    I0,
};
const ValueCount2 = enum {
    I0,
    I1,
};
const ValueCount256 = enum {
    I0,
    I1,
    I2,
    I3,
    I4,
    I5,
    I6,
    I7,
    I8,
    I9,
    I10,
    I11,
    I12,
    I13,
    I14,
    I15,
    I16,
    I17,
    I18,
    I19,
    I20,
    I21,
    I22,
    I23,
    I24,
    I25,
    I26,
    I27,
    I28,
    I29,
    I30,
    I31,
    I32,
    I33,
    I34,
    I35,
    I36,
    I37,
    I38,
    I39,
    I40,
    I41,
    I42,
    I43,
    I44,
    I45,
    I46,
    I47,
    I48,
    I49,
    I50,
    I51,
    I52,
    I53,
    I54,
    I55,
    I56,
    I57,
    I58,
    I59,
    I60,
    I61,
    I62,
    I63,
    I64,
    I65,
    I66,
    I67,
    I68,
    I69,
    I70,
    I71,
    I72,
    I73,
    I74,
    I75,
    I76,
    I77,
    I78,
    I79,
    I80,
    I81,
    I82,
    I83,
    I84,
    I85,
    I86,
    I87,
    I88,
    I89,
    I90,
    I91,
    I92,
    I93,
    I94,
    I95,
    I96,
    I97,
    I98,
    I99,
    I100,
    I101,
    I102,
    I103,
    I104,
    I105,
    I106,
    I107,
    I108,
    I109,
    I110,
    I111,
    I112,
    I113,
    I114,
    I115,
    I116,
    I117,
    I118,
    I119,
    I120,
    I121,
    I122,
    I123,
    I124,
    I125,
    I126,
    I127,
    I128,
    I129,
    I130,
    I131,
    I132,
    I133,
    I134,
    I135,
    I136,
    I137,
    I138,
    I139,
    I140,
    I141,
    I142,
    I143,
    I144,
    I145,
    I146,
    I147,
    I148,
    I149,
    I150,
    I151,
    I152,
    I153,
    I154,
    I155,
    I156,
    I157,
    I158,
    I159,
    I160,
    I161,
    I162,
    I163,
    I164,
    I165,
    I166,
    I167,
    I168,
    I169,
    I170,
    I171,
    I172,
    I173,
    I174,
    I175,
    I176,
    I177,
    I178,
    I179,
    I180,
    I181,
    I182,
    I183,
    I184,
    I185,
    I186,
    I187,
    I188,
    I189,
    I190,
    I191,
    I192,
    I193,
    I194,
    I195,
    I196,
    I197,
    I198,
    I199,
    I200,
    I201,
    I202,
    I203,
    I204,
    I205,
    I206,
    I207,
    I208,
    I209,
    I210,
    I211,
    I212,
    I213,
    I214,
    I215,
    I216,
    I217,
    I218,
    I219,
    I220,
    I221,
    I222,
    I223,
    I224,
    I225,
    I226,
    I227,
    I228,
    I229,
    I230,
    I231,
    I232,
    I233,
    I234,
    I235,
    I236,
    I237,
    I238,
    I239,
    I240,
    I241,
    I242,
    I243,
    I244,
    I245,
    I246,
    I247,
    I248,
    I249,
    I250,
    I251,
    I252,
    I253,
    I254,
    I255,
};
const ValueCount257 = enum {
    I0,
    I1,
    I2,
    I3,
    I4,
    I5,
    I6,
    I7,
    I8,
    I9,
    I10,
    I11,
    I12,
    I13,
    I14,
    I15,
    I16,
    I17,
    I18,
    I19,
    I20,
    I21,
    I22,
    I23,
    I24,
    I25,
    I26,
    I27,
    I28,
    I29,
    I30,
    I31,
    I32,
    I33,
    I34,
    I35,
    I36,
    I37,
    I38,
    I39,
    I40,
    I41,
    I42,
    I43,
    I44,
    I45,
    I46,
    I47,
    I48,
    I49,
    I50,
    I51,
    I52,
    I53,
    I54,
    I55,
    I56,
    I57,
    I58,
    I59,
    I60,
    I61,
    I62,
    I63,
    I64,
    I65,
    I66,
    I67,
    I68,
    I69,
    I70,
    I71,
    I72,
    I73,
    I74,
    I75,
    I76,
    I77,
    I78,
    I79,
    I80,
    I81,
    I82,
    I83,
    I84,
    I85,
    I86,
    I87,
    I88,
    I89,
    I90,
    I91,
    I92,
    I93,
    I94,
    I95,
    I96,
    I97,
    I98,
    I99,
    I100,
    I101,
    I102,
    I103,
    I104,
    I105,
    I106,
    I107,
    I108,
    I109,
    I110,
    I111,
    I112,
    I113,
    I114,
    I115,
    I116,
    I117,
    I118,
    I119,
    I120,
    I121,
    I122,
    I123,
    I124,
    I125,
    I126,
    I127,
    I128,
    I129,
    I130,
    I131,
    I132,
    I133,
    I134,
    I135,
    I136,
    I137,
    I138,
    I139,
    I140,
    I141,
    I142,
    I143,
    I144,
    I145,
    I146,
    I147,
    I148,
    I149,
    I150,
    I151,
    I152,
    I153,
    I154,
    I155,
    I156,
    I157,
    I158,
    I159,
    I160,
    I161,
    I162,
    I163,
    I164,
    I165,
    I166,
    I167,
    I168,
    I169,
    I170,
    I171,
    I172,
    I173,
    I174,
    I175,
    I176,
    I177,
    I178,
    I179,
    I180,
    I181,
    I182,
    I183,
    I184,
    I185,
    I186,
    I187,
    I188,
    I189,
    I190,
    I191,
    I192,
    I193,
    I194,
    I195,
    I196,
    I197,
    I198,
    I199,
    I200,
    I201,
    I202,
    I203,
    I204,
    I205,
    I206,
    I207,
    I208,
    I209,
    I210,
    I211,
    I212,
    I213,
    I214,
    I215,
    I216,
    I217,
    I218,
    I219,
    I220,
    I221,
    I222,
    I223,
    I224,
    I225,
    I226,
    I227,
    I228,
    I229,
    I230,
    I231,
    I232,
    I233,
    I234,
    I235,
    I236,
    I237,
    I238,
    I239,
    I240,
    I241,
    I242,
    I243,
    I244,
    I245,
    I246,
    I247,
    I248,
    I249,
    I250,
    I251,
    I252,
    I253,
    I254,
    I255,
    I256,
};

test "enum sizes" {
    comptime {
        try expect(@sizeOf(ValueCount1) == 0);
        try expect(@sizeOf(ValueCount2) == 1);
        try expect(@sizeOf(ValueCount256) == 1);
        try expect(@sizeOf(ValueCount257) == 2);
    }
}

test "enum literal equality" {
    const x = .hi;
    const y = .ok;
    const z = .hi;

    try expect(x != y);
    try expect(x == z);
}

test "enum literal cast to enum" {
    const Color = enum { Auto, Off, On };

    var color1: Color = .Auto;
    var color2 = Color.Auto;
    _ = .{ &color1, &color2 };
    try expect(color1 == color2);
}

test "peer type resolution with enum literal" {
    const Items = enum { one, two };

    try expect(Items.two == .two);
    try expect(.two == Items.two);
}

const MultipleChoice = enum(u32) {
    A = 20,
    B = 40,
    C = 60,
    D = 1000,
};

fn testEnumWithSpecifiedTagValues(x: MultipleChoice) !void {
    try expect(@intFromEnum(x) == 60);
    try expect(1234 == switch (x) {
        MultipleChoice.A => 1,
        MultipleChoice.B => 2,
        MultipleChoice.C => @as(u32, 1234),
        MultipleChoice.D => 4,
    });
}

test "enum with specified tag values" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testEnumWithSpecifiedTagValues(MultipleChoice.C);
    try comptime testEnumWithSpecifiedTagValues(MultipleChoice.C);
}

test "non-exhaustive enum" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        const E = enum(u8) { a, b, _ };

        fn doTheTest(y: u8) !void {
            var e: E = .b;
            try expect(switch (e) {
                .a => false,
                .b => true,
                _ => false,
            });
            e = @as(E, @enumFromInt(12));
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
            e = @as(E, @enumFromInt(12));
            try expect(@intFromEnum(e) == 12);
            e = @as(E, @enumFromInt(y));
            try expect(@intFromEnum(e) == 52);
            try expect(@typeInfo(E).Enum.is_exhaustive == false);
        }
    };
    try S.doTheTest(52);
    try comptime S.doTheTest(52);
}

test "empty non-exhaustive enum" {
    const S = struct {
        const E = enum(u8) { _ };

        fn doTheTest(y: u8) !void {
            var e: E = @enumFromInt(y);
            _ = &e;
            try expect(switch (e) {
                _ => true,
            });
            try expect(@intFromEnum(e) == y);

            try expect(@typeInfo(E).Enum.fields.len == 0);
            try expect(@typeInfo(E).Enum.is_exhaustive == false);
        }
    };
    try S.doTheTest(42);
    try comptime S.doTheTest(42);
}

test "single field non-exhaustive enum" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        const E = enum(u8) { a, _ };
        fn doTheTest(y: u8) !void {
            var e: E = .a;
            try expect(switch (e) {
                .a => true,
                _ => false,
            });
            e = @as(E, @enumFromInt(12));
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

            try expect(@intFromEnum(@as(E, @enumFromInt(y))) == y);
            try expect(@typeInfo(E).Enum.fields.len == 1);
            try expect(@typeInfo(E).Enum.is_exhaustive == false);
        }
    };
    try S.doTheTest(23);
    try comptime S.doTheTest(23);
}

const EnumWithTagValues = enum(u4) {
    A = 1 << 0,
    B = 1 << 1,
    C = 1 << 2,
    D = 1 << 3,
};
test "enum with tag values don't require parens" {
    try expect(@intFromEnum(EnumWithTagValues.C) == 0b0100);
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

test "cast integer literal to enum" {
    try expect(@as(MultipleChoice2, @enumFromInt(0)) == MultipleChoice2.Unspecified1);
    try expect(@as(MultipleChoice2, @enumFromInt(40)) == MultipleChoice2.B);
}

test "enum with specified and unspecified tag values" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testEnumWithSpecifiedAndUnspecifiedTagValues(MultipleChoice2.D);
    try comptime testEnumWithSpecifiedAndUnspecifiedTagValues(MultipleChoice2.D);
}

fn testEnumWithSpecifiedAndUnspecifiedTagValues(x: MultipleChoice2) !void {
    try expect(@intFromEnum(x) == 1000);
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

const Small2 = enum(u2) { One, Two };
const Small = enum(u2) { One, Two, Three, Four };

test "set enum tag type" {
    {
        var x = Small.One;
        x = Small.Two;
        comptime assert(Tag(Small) == u2);
    }
    {
        var x = Small2.One;
        x = Small2.Two;
        comptime assert(Tag(Small2) == u2);
    }
}

test "casting enum to its tag type" {
    try testCastEnumTag(Small2.Two);
    try comptime testCastEnumTag(Small2.Two);
}

fn testCastEnumTag(value: Small2) !void {
    try expect(@intFromEnum(value) == 1);
}

test "enum with 1 field but explicit tag type should still have the tag type" {
    const Enum = enum(u8) {
        B = 2,
    };
    comptime assert(@sizeOf(Enum) == @sizeOf(u8));
}

test "signed integer as enum tag" {
    const SignedEnum = enum(i2) {
        A0 = -1,
        A1 = 0,
        A2 = 1,
    };

    try expect(@intFromEnum(SignedEnum.A0) == -1);
    try expect(@intFromEnum(SignedEnum.A1) == 0);
    try expect(@intFromEnum(SignedEnum.A2) == 1);
}

test "enum with one member and custom tag type" {
    const E = enum(u2) {
        One,
    };
    try expect(@intFromEnum(E.One) == 0);
    const E2 = enum(u2) {
        One = 2,
    };
    try expect(@intFromEnum(E2.One) == 2);
}

test "enum with one member and u1 tag type @intFromEnum" {
    const Enum = enum(u1) {
        Test,
    };
    try expect(@intFromEnum(Enum.Test) == 0);
}

test "enum with comptime_int tag type" {
    const Enum = enum(comptime_int) {
        One = 3,
        Two = 2,
        Three = 1,
    };
    comptime assert(Tag(Enum) == comptime_int);
}

test "enum with one member default to u0 tag type" {
    const E0 = enum { X };
    comptime assert(Tag(E0) == u0);
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

test "comparison operator on enum with one member is comptime-known" {
    doALoopThing(EnumWithOneMember.Eof);
}

const State = enum { Start };
test "switch on enum with one member is comptime-known" {
    var state = State.Start;
    _ = &state;
    switch (state) {
        State.Start => return,
    }
    @compileError("analysis should not reach here");
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
    try comptime S.doTheTest();
}

test "enum value allocation" {
    const LargeEnum = enum(u32) {
        A0 = 0x80000000,
        A1,
        A2,
    };

    try expect(@intFromEnum(LargeEnum.A0) == 0x80000000);
    try expect(@intFromEnum(LargeEnum.A1) == 0x80000001);
    try expect(@intFromEnum(LargeEnum.A2) == 0x80000002);
}

test "enum literal casting to tagged union" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    _ = .{ &t, &x };
    const y = if (t) x else .x86_64;
    switch (y) {
        .x86_64 => {},
        else => @panic("fail"),
    }
}

const Bar = enum { A, B, C, D };

test "enum literal casting to error union with payload enum" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var bar: error{B}!Bar = undefined;
    bar = .B; // should never cast to the error set

    try expect((try bar) == Bar.B);
}

test "constant enum initialization with differing sizes" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try test3_1(test3_foo);
    try test3_2(test3_bar);
}
const Test3Foo = union(enum) {
    One: void,
    Two: f32,
    Three: Test3Point,
};
const Test3Point = struct {
    x: i32,
    y: i32,
};
const test3_foo = Test3Foo{
    .Three = Test3Point{
        .x = 3,
        .y = 4,
    },
};
const test3_bar = Test3Foo{ .Two = 13 };
fn test3_1(f: Test3Foo) !void {
    switch (f) {
        Test3Foo.Three => |pt| {
            try expect(pt.x == 3);
            try expect(pt.y == 4);
        },
        else => unreachable,
    }
}
fn test3_2(f: Test3Foo) !void {
    switch (f) {
        Test3Foo.Two => |x| {
            try expect(x == 13);
        },
        else => unreachable,
    }
}

test "@tagName" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try expect(mem.eql(u8, testEnumTagNameBare(BareNumber.Three), "Three"));
    comptime assert(mem.eql(u8, testEnumTagNameBare(BareNumber.Three), "Three"));
}

fn testEnumTagNameBare(n: anytype) []const u8 {
    return @tagName(n);
}

const BareNumber = enum { One, Two, Three };

test "@tagName non-exhaustive enum" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try expect(mem.eql(u8, testEnumTagNameBare(NonExhaustive.B), "B"));
    comptime assert(mem.eql(u8, testEnumTagNameBare(NonExhaustive.B), "B"));
}
const NonExhaustive = enum(u8) { A, B, _ };

test "@tagName is null-terminated" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest(n: BareNumber) !void {
            try expect(@tagName(n)[3] == 0);
        }
    };
    try S.doTheTest(.Two);
    try comptime S.doTheTest(.Two);
}

test "tag name with assigned enum values" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const LocalFoo = enum(u8) {
        A = 1,
        B = 0,
    };
    var b = LocalFoo.B;
    _ = &b;
    try expect(mem.eql(u8, @tagName(b), "B"));
}

test "@tagName on enum literals" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(mem.eql(u8, @tagName(.FooBar), "FooBar"));
    comptime assert(mem.eql(u8, @tagName(.FooBar), "FooBar"));
}

test "tag name with signed enum values" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const LocalFoo = enum(isize) {
        alfa = 62,
        bravo = 63,
        charlie = 64,
        delta = 65,
    };
    var b = LocalFoo.bravo;
    _ = &b;
    try expect(mem.eql(u8, @tagName(b), "bravo"));
}

test "enum literal casting to optional" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var data = bit_field_1;
    try expect(getA(&data) == A.Two);
    try expect(getB(&data) == B.Three3);
    try expect(getC(&data) == C.Four4);
    comptime assert(@sizeOf(BitFieldOfEnums) == 1);

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

test "enum literal in array literal" {
    const Items = enum { one, two };
    const array = [_]Items{ .one, .two };

    try expect(array[0] == .one);
    try expect(array[1] == .two);
}

test "tag name functions are unique" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    {
        const E = enum { a, b };
        var b = E.a;
        var a = @tagName(b);
        _ = .{ &a, &b };
    }
    {
        const E = enum { a, b, c, d, e, f };
        var b = E.a;
        var a = @tagName(b);
        _ = .{ &a, &b };
    }
}

test "size of enum with only one tag which has explicit integer tag type" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const E = enum(u8) { nope = 10 };
    const S0 = struct { e: E };
    const S1 = extern struct { e: E };
    //const U = union(E) { nope: void };
    comptime assert(@sizeOf(E) == 1);
    comptime assert(@sizeOf(S0) == 1);
    comptime assert(@sizeOf(S1) == 1);
    //comptime assert(@sizeOf(U) == 1);

    var s1: S1 = undefined;
    s1.e = .nope;
    try expect(s1.e == .nope);
    const ptr = @as(*u8, @ptrCast(&s1));
    try expect(ptr.* == 10);

    var s0: S0 = undefined;
    s0.e = .nope;
    try expect(s0.e == .nope);
}

test "switch on an extern enum with negative value" {
    const Foo = enum(c_int) {
        Bar = -1,
    };

    const v = Foo.Bar;

    switch (v) {
        Foo.Bar => return,
    }
}

test "Non-exhaustive enum with nonstandard int size behaves correctly" {
    const E = enum(u15) { _ };
    try expect(@sizeOf(E) == @sizeOf(u15));
}

test "runtime int to enum with one possible value" {
    const E = enum { one };
    var runtime: usize = 0;
    _ = &runtime;
    if (@as(E, @enumFromInt(runtime)) != .one) {
        @compileError("test failed");
    }
}

test "enum tag from a local variable" {
    const S = struct {
        fn Int(comptime Inner: type) type {
            return enum(Inner) { _ };
        }
    };
    const i = @as(S.Int(u32), @enumFromInt(0));
    try std.testing.expect(@intFromEnum(i) == 0);
}

test "auto-numbered enum with signed tag type" {
    const E = enum(i32) { a, b };

    try std.testing.expectEqual(@as(i32, 0), @intFromEnum(E.a));
    try std.testing.expectEqual(@as(i32, 1), @intFromEnum(E.b));
    try std.testing.expectEqual(E.a, @as(E, @enumFromInt(0)));
    try std.testing.expectEqual(E.b, @as(E, @enumFromInt(1)));
    try std.testing.expectEqual(E.a, @as(E, @enumFromInt(@as(i32, 0))));
    try std.testing.expectEqual(E.b, @as(E, @enumFromInt(@as(i32, 1))));
    try std.testing.expectEqual(E.a, @as(E, @enumFromInt(@as(u32, 0))));
    try std.testing.expectEqual(E.b, @as(E, @enumFromInt(@as(u32, 1))));
    try std.testing.expectEqualStrings("a", @tagName(E.a));
    try std.testing.expectEqualStrings("b", @tagName(E.b));
}

test "lazy initialized field" {
    try std.testing.expectEqual(@as(u8, @alignOf(struct {})), getLazyInitialized(.a));
}

fn getLazyInitialized(param: enum(u8) {
    a = @bitCast(packed struct(u8) { a: u8 }{ .a = @alignOf(struct {}) }),
}) u8 {
    return @intFromEnum(param);
}

test "Non-exhaustive enum backed by comptime_int" {
    const E = enum(comptime_int) { a, b, c, _ };
    comptime var e: E = .a;
    e = @as(E, @enumFromInt(378089457309184723749));
    try expect(@intFromEnum(e) == 378089457309184723749);
}

test "matching captures causes enum equivalence" {
    const S = struct {
        fn Nonexhaustive(comptime I: type) type {
            const UTag = @Type(.{ .Int = .{
                .signedness = .unsigned,
                .bits = @typeInfo(I).Int.bits,
            } });
            return enum(UTag) { _ };
        }
    };

    comptime assert(S.Nonexhaustive(u8) == S.Nonexhaustive(i8));
    comptime assert(S.Nonexhaustive(u16) == S.Nonexhaustive(i16));
    comptime assert(S.Nonexhaustive(u8) != S.Nonexhaustive(u16));

    const a: S.Nonexhaustive(u8) = @enumFromInt(123);
    const b: S.Nonexhaustive(i8) = @enumFromInt(123);
    comptime assert(@TypeOf(a) == @TypeOf(b));
    try expect(@intFromEnum(a) == @intFromEnum(b));
}

test "large enum field values" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;

    {
        const E = enum(u64) { min = std.math.minInt(u64), max = std.math.maxInt(u64) };
        var e: E = .min;
        try expect(e == .min);
        try expect(@intFromEnum(e) == std.math.minInt(u64));
        e = .max;
        try expect(e == .max);
        try expect(@intFromEnum(e) == std.math.maxInt(u64));
    }
    {
        const E = enum(i64) { min = std.math.minInt(i64), max = std.math.maxInt(i64) };
        var e: E = .min;
        try expect(e == .min);
        try expect(@intFromEnum(e) == std.math.minInt(i64));
        e = .max;
        try expect(e == .max);
        try expect(@intFromEnum(e) == std.math.maxInt(i64));
    }
    {
        const E = enum(u128) { min = std.math.minInt(u128), max = std.math.maxInt(u128) };
        var e: E = .min;
        try expect(e == .min);
        try expect(@intFromEnum(e) == std.math.minInt(u128));
        e = .max;
        try expect(e == .max);
        try expect(@intFromEnum(e) == std.math.maxInt(u128));
    }
    {
        const E = enum(i128) { min = std.math.minInt(i128), max = std.math.maxInt(i128) };
        var e: E = .min;
        try expect(e == .min);
        try expect(@intFromEnum(e) == std.math.minInt(i128));
        e = .max;
        try expect(e == .max);
        try expect(@intFromEnum(e) == std.math.maxInt(i128));
    }
}
