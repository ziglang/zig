const builtin = @import("builtin");
const std = @import("std");
const endian = builtin.cpu.arch.endian();
const expect = std.testing.expect;
const assert = std.debug.assert;
const expectEqual = std.testing.expectEqual;
const Tag = std.meta.Tag;

const FooWithFloats = union {
    float: f64,
    int: i32,
};

test "basic unions with floats" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var foo = FooWithFloats{ .int = 1 };
    try expect(foo.int == 1);
    foo = FooWithFloats{ .float = 12.34 };
    try expect(foo.float == 12.34);
}

fn setFloat(foo: *FooWithFloats, x: f64) void {
    foo.* = FooWithFloats{ .float = x };
}

test "init union with runtime value - floats" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var foo: FooWithFloats = undefined;

    setFloat(&foo, 12.34);
    try expect(foo.float == 12.34);
}

test "basic unions" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var foo = Foo{ .int = 1 };
    try expect(foo.int == 1);
    foo = Foo{ .str = .{ .slice = "Hello!" } };
    try expect(std.mem.eql(u8, foo.str.slice, "Hello!"));
}

const Foo = union {
    int: i32,
    str: struct {
        slice: []const u8,
    },
};

test "init union with runtime value" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var foo: Foo = undefined;

    setInt(&foo, 42);
    try expect(foo.int == 42);

    setStr(&foo, "Hello!");
    try expect(std.mem.eql(u8, foo.str.slice, "Hello!"));
}

fn setInt(foo: *Foo, x: i32) void {
    foo.* = Foo{ .int = x };
}

fn setStr(foo: *Foo, slice: []const u8) void {
    foo.* = Foo{ .str = .{ .slice = slice } };
}

test "comptime union field access" {
    comptime {
        var foo = FooWithFloats{ .int = 0 };
        try expect(foo.int == 0);

        foo = FooWithFloats{ .float = 12.34 };
        try expect(foo.float == 12.34);
    }
}

const FooExtern = extern union {
    int: i32,
    str: extern struct {
        slice: [*:0]const u8,
    },
};

test "basic extern unions" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var foo = FooExtern{ .int = 1 };
    try expect(foo.int == 1);
    foo.str.slice = "Well";
    try expect(std.mem.eql(u8, std.mem.sliceTo(foo.str.slice, 0), "Well"));
}

const ExternPtrOrInt = extern union {
    ptr: *u8,
    int: u64,
};
test "extern union size" {
    comptime assert(@sizeOf(ExternPtrOrInt) == 8);
}

test "0-sized extern union definition" {
    const U = extern union {
        a: void,
        const f = 1;
    };

    try expect(U.f == 1);
}

const Value = union(enum) {
    Int: u64,
    Array: [9]u8,
};

const Agg = struct {
    val1: Value,
    val2: Value,
};

const v1 = Value{ .Int = 1234 };
const v2 = Value{ .Array = [_]u8{3} ** 9 };

const err = @as(anyerror!Agg, Agg{
    .val1 = v1,
    .val2 = v2,
});

const array = [_]Value{ v1, v2, v1, v2 };

test "unions embedded in aggregate types" {
    switch (array[1]) {
        Value.Array => |arr| try expect(arr[4] == 3),
        else => unreachable,
    }
    switch ((err catch unreachable).val1) {
        Value.Int => |x| try expect(x == 1234),
        else => unreachable,
    }
}

test "access a member of tagged union with conflicting enum tag name" {
    const Bar = union(enum) {
        A: A,
        B: B,

        const A = u8;
        const B = void;
    };

    comptime assert(Bar.A == u8);
}

test "constant tagged union with payload" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var empty = TaggedUnionWithPayload{ .Empty = {} };
    var full = TaggedUnionWithPayload{ .Full = 13 };
    _ = .{ &empty, &full };
    shouldBeEmpty(empty);
    shouldBeNotEmpty(full);
}

fn shouldBeEmpty(x: TaggedUnionWithPayload) void {
    switch (x) {
        TaggedUnionWithPayload.Empty => {},
        else => unreachable,
    }
}

fn shouldBeNotEmpty(x: TaggedUnionWithPayload) void {
    switch (x) {
        TaggedUnionWithPayload.Empty => unreachable,
        else => {},
    }
}

const TaggedUnionWithPayload = union(enum) {
    Empty: void,
    Full: i32,
};

test "union alignment" {
    comptime {
        try expect(@alignOf(AlignTestTaggedUnion) >= @alignOf([9]u8));
        try expect(@alignOf(AlignTestTaggedUnion) >= @alignOf(u64));
    }
}

const AlignTestTaggedUnion = union(enum) {
    A: [9]u8,
    B: u64,
};

const Letter = enum { A, B, C };
const Payload = union(Letter) {
    A: i32,
    B: f64,
    C: bool,
};

test "union with specified enum tag" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try doTest();
    try comptime doTest();
}

test "packed union generates correctly aligned type" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const U = packed union {
        f1: *const fn () error{TestUnexpectedResult}!void,
        f2: u32,
    };
    var foo = [_]U{
        U{ .f1 = doTest },
        U{ .f2 = 0 },
    };
    try foo[0].f1();
}

fn doTest() error{TestUnexpectedResult}!void {
    try expect((try bar(Payload{ .A = 1234 })) == -10);
}

fn bar(value: Payload) error{TestUnexpectedResult}!i32 {
    try expect(@as(Letter, value) == Letter.A);
    return switch (value) {
        Payload.A => |x| return x - 1244,
        Payload.B => |x| if (x == 12.34) @as(i32, 20) else 21,
        Payload.C => |x| if (x) @as(i32, 30) else 31,
    };
}

fn testComparison() !void {
    var x = Payload{ .A = 42 };
    _ = &x;
    try expect(x == .A);
    try expect(x != .B);
    try expect(x != .C);
    try expect((x == .B) == false);
    try expect((x == .C) == false);
    try expect((x != .A) == false);
}

test "comparison between union and enum literal" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testComparison();
    try comptime testComparison();
}

const TheTag = enum { A, B, C };
const TheUnion = union(TheTag) {
    A: i32,
    B: i32,
    C: i32,
};
test "cast union to tag type of union" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testCastUnionToTag();
    try comptime testCastUnionToTag();
}

fn testCastUnionToTag() !void {
    var u = TheUnion{ .B = 1234 };
    _ = &u;
    try expect(@as(TheTag, u) == TheTag.B);
}

test "union field access gives the enum values" {
    try expect(TheUnion.A == TheTag.A);
    try expect(TheUnion.B == TheTag.B);
    try expect(TheUnion.C == TheTag.C);
}

test "cast tag type of union to union" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var x: Value2 = Letter2.B;
    _ = &x;
    try expect(@as(Letter2, x) == Letter2.B);
}
const Letter2 = enum { A, B, C };
const Value2 = union(Letter2) {
    A: i32,
    B,
    C,
};

test "implicit cast union to its tag type" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var x: Value2 = Letter2.B;
    _ = &x;
    try expect(x == Letter2.B);
    try giveMeLetterB(x);
}
fn giveMeLetterB(x: Letter2) !void {
    try expect(x == Value2.B);
}

// TODO it looks like this test intended to test packed unions, but this is not a packed
// union. go through git history and find out what happened.
pub const PackThis = union(enum) {
    Invalid: bool,
    StringLiteral: u2,
};

test "constant packed union" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testConstPackedUnion(&[_]PackThis{PackThis{ .StringLiteral = 1 }});
}

fn testConstPackedUnion(expected_tokens: []const PackThis) !void {
    try expect(expected_tokens[0].StringLiteral == 1);
}

const MultipleChoice = union(enum(u32)) {
    A = 20,
    B = 40,
    C = 60,
    D = 1000,
};
test "simple union(enum(u32))" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var x = MultipleChoice.C;
    _ = &x;
    try expect(x == MultipleChoice.C);
    try expect(@intFromEnum(@as(Tag(MultipleChoice), x)) == 60);
}

const PackedPtrOrInt = packed union {
    ptr: *u8,
    int: u64,
};
test "packed union size" {
    comptime assert(@sizeOf(PackedPtrOrInt) == 8);
}

const ZeroBits = union {
    OnlyField: void,
};
test "union with only 1 field which is void should be zero bits" {
    comptime assert(@sizeOf(ZeroBits) == 0);
}

test "assigning to union with zero size field" {
    const U = union {
        a: u32,
        b: void,
        c: f32,
    };

    const u: U = .{ .b = {} };
    _ = u;

    const UE = union(enum) {
        a: f32,
        b: u32,
        c: u0,
    };

    const ue: UE = .{ .c = 0 };
    _ = ue;
}

test "tagged union initialization with runtime void" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try expect(testTaggedUnionInit({}));
}

const TaggedUnionWithAVoid = union(enum) {
    A,
    B: i32,
};

fn testTaggedUnionInit(x: anytype) bool {
    const y = TaggedUnionWithAVoid{ .A = x };
    return @as(Tag(TaggedUnionWithAVoid), y) == TaggedUnionWithAVoid.A;
}

pub const UnionEnumNoPayloads = union(enum) { A, B };

test "tagged union with no payloads" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const a = UnionEnumNoPayloads{ .B = {} };
    switch (a) {
        Tag(UnionEnumNoPayloads).A => @panic("wrong"),
        Tag(UnionEnumNoPayloads).B => {},
    }
}

test "union with only 1 field casted to its enum type" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const Literal = union(enum) {
        Number: f64,
        Bool: bool,
    };

    const Expr = union(enum) {
        Literal: Literal,
    };

    var e = Expr{ .Literal = Literal{ .Bool = true } };
    _ = &e;
    const ExprTag = Tag(Expr);
    comptime assert(Tag(ExprTag) == u0);
    var t = @as(ExprTag, e);
    _ = &t;
    try expect(t == Expr.Literal);
}

test "union with one member defaults to u0 tag type" {
    const U0 = union(enum) {
        X: u32,
    };
    comptime assert(Tag(Tag(U0)) == u0);
}

const Foo1 = union(enum) {
    f: struct {
        x: usize,
    },
};
var glbl: Foo1 = undefined;

test "global union with single field is correctly initialized" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    glbl = Foo1{
        .f = @typeInfo(Foo1).Union.fields[0].type{ .x = 123 },
    };
    try expect(glbl.f.x == 123);
}

pub const FooUnion = union(enum) {
    U0: usize,
    U1: u8,
};

var glbl_array: [2]FooUnion = undefined;

test "initialize global array of union" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    glbl_array[1] = FooUnion{ .U1 = 2 };
    glbl_array[0] = FooUnion{ .U0 = 1 };
    try expect(glbl_array[0].U0 == 1);
    try expect(glbl_array[1].U1 == 2);
}

test "update the tag value for zero-sized unions" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = union(enum) {
        U0: void,
        U1: void,
    };
    var x = S{ .U0 = {} };
    try expect(x == .U0);
    x = S{ .U1 = {} };
    try expect(x == .U1);
}

test "union initializer generates padding only if needed" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const U = union(enum) {
        A: u24,
    };

    var v = U{ .A = 532 };
    _ = &v;
    try expect(v.A == 532);
}

test "runtime tag name with single field" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const U = union(enum) {
        A: i32,
    };

    var v = U{ .A = 42 };
    _ = &v;
    try expect(std.mem.eql(u8, @tagName(v), "A"));
}

test "method call on an empty union" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        const MyUnion = union(MyUnionTag) {
            pub const MyUnionTag = enum { X1, X2 };
            X1: [0]u8,
            X2: [0]u8,

            pub fn useIt(self: *@This()) bool {
                _ = self;
                return true;
            }
        };

        fn doTheTest() !void {
            var u = MyUnion{ .X1 = [0]u8{} };
            try expect(u.useIt());
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

const Point = struct {
    x: u64,
    y: u64,
};
const TaggedFoo = union(enum) {
    One: i32,
    Two: Point,
    Three: void,
};
const FooNoVoid = union(enum) {
    One: i32,
    Two: Point,
};
const Baz = enum { A, B, C, D };

test "tagged union type" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const foo1 = TaggedFoo{ .One = 13 };
    const foo2 = TaggedFoo{
        .Two = Point{
            .x = 1234,
            .y = 5678,
        },
    };
    try expect(foo1.One == 13);
    try expect(foo2.Two.x == 1234 and foo2.Two.y == 5678);
    const baz = Baz.B;

    try expect(baz == Baz.B);
    try expect(@typeInfo(TaggedFoo).Union.fields.len == 3);
    try expect(@typeInfo(Baz).Enum.fields.len == 4);
    try expect(@sizeOf(TaggedFoo) == @sizeOf(FooNoVoid));
    try expect(@sizeOf(Baz) == 1);
}

test "tagged union as return value" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    switch (returnAnInt(13)) {
        TaggedFoo.One => |value| try expect(value == 13),
        else => unreachable,
    }
}

fn returnAnInt(x: i32) TaggedFoo {
    return TaggedFoo{ .One = x };
}

test "tagged union with all void fields but a meaningful tag" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        const B = union(enum) {
            c: C,
            None,
        };

        const A = struct {
            b: B,
        };

        const C = struct {};

        fn doTheTest() !void {
            var a: A = A{ .b = B{ .c = C{} } };
            try expect(@as(Tag(B), a.b) == Tag(B).c);
            a = A{ .b = B.None };
            try expect(@as(Tag(B), a.b) == Tag(B).None);
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "union(enum(u32)) with specified and unspecified tag values" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    comptime assert(Tag(Tag(MultipleChoice2)) == u32);
    try testEnumWithSpecifiedAndUnspecifiedTagValues(MultipleChoice2{ .C = 123 });
    try comptime testEnumWithSpecifiedAndUnspecifiedTagValues(MultipleChoice2{ .C = 123 });
}

const MultipleChoice2 = union(enum(u32)) {
    Unspecified1: i32,
    A: f32 = 20,
    Unspecified2: void,
    B: bool = 40,
    Unspecified3: i32,
    C: i8 = 60,
    Unspecified4: void,
    D: void = 1000,
    Unspecified5: i32,
};

fn testEnumWithSpecifiedAndUnspecifiedTagValues(x: MultipleChoice2) !void {
    try expect(@intFromEnum(@as(Tag(MultipleChoice2), x)) == 60);
    try expect(1123 == switch (x) {
        MultipleChoice2.A => 1,
        MultipleChoice2.B => 2,
        MultipleChoice2.C => |v| @as(i32, 1000) + v,
        MultipleChoice2.D => 4,
        MultipleChoice2.Unspecified1 => 5,
        MultipleChoice2.Unspecified2 => 6,
        MultipleChoice2.Unspecified3 => 7,
        MultipleChoice2.Unspecified4 => 8,
        MultipleChoice2.Unspecified5 => 9,
    });
}

test "switch on union with only 1 field" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var r: PartialInst = undefined;
    r = PartialInst.Compiled;
    switch (r) {
        PartialInst.Compiled => {
            var z: PartialInstWithPayload = undefined;
            z = PartialInstWithPayload{ .Compiled = 1234 };
            switch (z) {
                PartialInstWithPayload.Compiled => |x| {
                    try expect(x == 1234);
                    return;
                },
            }
        },
    }
    unreachable;
}

const PartialInst = union(enum) {
    Compiled,
};

const PartialInstWithPayload = union(enum) {
    Compiled: i32,
};

test "union with only 1 field casted to its enum type which has enum value specified" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const Literal = union(enum) {
        Number: f64,
        Bool: bool,
    };

    const ExprTag = enum(comptime_int) {
        Literal = 33,
    };

    const Expr = union(ExprTag) {
        Literal: Literal,
    };

    var e = Expr{ .Literal = Literal{ .Bool = true } };
    _ = &e;
    comptime assert(Tag(ExprTag) == comptime_int);
    const t = comptime @as(ExprTag, e);
    try expect(t == Expr.Literal);
    try expect(@intFromEnum(t) == 33);
    comptime assert(@intFromEnum(t) == 33);
}

test "@intFromEnum works on unions" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const Bar = union(enum) {
        A: bool,
        B: u8,
        C,
    };

    const a = Bar{ .A = true };
    var b = Bar{ .B = undefined };
    var c = Bar.C;
    _ = .{ &b, &c };
    try expect(@intFromEnum(a) == 0);
    try expect(@intFromEnum(b) == 1);
    try expect(@intFromEnum(c) == 2);
}

test "comptime union field value equality" {
    const a0 = Setter(Attribute{ .A = false });
    const a1 = Setter(Attribute{ .A = true });
    const a2 = Setter(Attribute{ .A = false });

    const b0 = Setter(Attribute{ .B = 5 });
    const b1 = Setter(Attribute{ .B = 9 });
    const b2 = Setter(Attribute{ .B = 5 });

    try expect(a0 == a0);
    try expect(a1 == a1);
    try expect(a0 == a2);

    try expect(b0 == b0);
    try expect(b1 == b1);
    try expect(b0 == b2);

    try expect(a0 != b0);
    try expect(a0 != a1);
    try expect(b0 != b1);
}

const Attribute = union(enum) {
    A: bool,
    B: u8,
};

fn setAttribute(attr: Attribute) void {
    _ = attr;
}

fn Setter(comptime attr: Attribute) type {
    return struct {
        fn set() void {
            setAttribute(attr);
        }
    };
}

test "return union init with void payload" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn entry() !void {
            try expect(func().state == State.one);
        }
        const Outer = union(enum) {
            state: State,
        };
        const State = union(enum) {
            one: void,
            two: u32,
        };
        fn func() Outer {
            return Outer{ .state = State{ .one = {} } };
        }
    };
    try S.entry();
    try comptime S.entry();
}

test "@unionInit stored to a const" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        const U = union(enum) {
            boolean: bool,
            byte: u8,
        };
        fn doTheTest() !void {
            {
                var t = true;
                _ = &t;
                const u = @unionInit(U, "boolean", t);
                try expect(u.boolean);
            }
            {
                var byte: u8 = 69;
                _ = &byte;
                const u = @unionInit(U, "byte", byte);
                try expect(u.byte == 69);
            }
        }
    };

    try comptime S.doTheTest();
    try S.doTheTest();
}

test "@unionInit can modify a union type" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const UnionInitEnum = union(enum) {
        Boolean: bool,
        Byte: u8,
    };

    var value: UnionInitEnum = undefined;

    value = @unionInit(UnionInitEnum, "Boolean", true);
    try expect(value.Boolean == true);
    value.Boolean = false;
    try expect(value.Boolean == false);

    value = @unionInit(UnionInitEnum, "Byte", 2);
    try expect(value.Byte == 2);
    value.Byte = 3;
    try expect(value.Byte == 3);
}

test "@unionInit can modify a pointer value" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const UnionInitEnum = union(enum) {
        Boolean: bool,
        Byte: u8,
    };

    var value: UnionInitEnum = undefined;
    const value_ptr = &value;

    value_ptr.* = @unionInit(UnionInitEnum, "Boolean", true);
    try expect(value.Boolean == true);

    value_ptr.* = @unionInit(UnionInitEnum, "Byte", 2);
    try expect(value.Byte == 2);
}

test "union no tag with struct member" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const Struct = struct {};
    const Union = union {
        s: Struct,
        pub fn foo(self: *@This()) void {
            _ = self;
        }
    };
    var u = Union{ .s = Struct{} };
    u.foo();
}

test "union with comptime_int tag" {
    const Union = union(enum(comptime_int)) {
        X: u32,
        Y: u16,
        Z: u8,
    };
    comptime assert(Tag(Tag(Union)) == comptime_int);
}

test "extern union doesn't trigger field check at comptime" {
    const U = extern union {
        x: u32,
        y: u8,
    };

    const x = U{ .x = 0x55AAAA55 };
    comptime assert(x.y == 0x55);
}

test "anonymous union literal syntax" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        const Number = union {
            int: i32,
            float: f64,
        };

        fn doTheTest() !void {
            var i: Number = .{ .int = 42 };
            _ = &i;
            const f = makeNumber();
            try expect(i.int == 42);
            try expect(f.float == 12.34);
        }

        fn makeNumber() Number {
            return .{ .float = 12.34 };
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "function call result coerces from tagged union to the tag" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        const Arch = union(enum) {
            One,
            Two: usize,
        };

        const ArchTag = Tag(Arch);

        fn doTheTest() !void {
            var x: ArchTag = getArch1();
            _ = &x;
            try expect(x == .One);

            var y: ArchTag = getArch2();
            _ = &y;
            try expect(y == .Two);
        }

        pub fn getArch1() Arch {
            return .One;
        }

        pub fn getArch2() Arch {
            return .{ .Two = 99 };
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "cast from anonymous struct to union" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        const U = union(enum) {
            A: u32,
            B: []const u8,
            C: void,
        };
        fn doTheTest() !void {
            var y: u32 = 42;
            _ = &y;
            const t0 = .{ .A = 123 };
            const t1 = .{ .B = "foo" };
            const t2 = .{ .C = {} };
            const t3 = .{ .A = y };
            const x0: U = t0;
            var x1: U = t1;
            _ = &x1;
            const x2: U = t2;
            var x3: U = t3;
            _ = &x3;
            try expect(x0.A == 123);
            try expect(std.mem.eql(u8, x1.B, "foo"));
            try expect(x2 == .C);
            try expect(x3.A == y);
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "cast from pointer to anonymous struct to pointer to union" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        const U = union(enum) {
            A: u32,
            B: []const u8,
            C: void,
        };
        fn doTheTest() !void {
            var y: u32 = 42;
            _ = &y;
            const t0 = &.{ .A = 123 };
            const t1 = &.{ .B = "foo" };
            const t2 = &.{ .C = {} };
            const t3 = &.{ .A = y };
            const x0: *const U = t0;
            var x1: *const U = t1;
            _ = &x1;
            const x2: *const U = t2;
            var x3: *const U = t3;
            _ = &x3;
            try expect(x0.A == 123);
            try expect(std.mem.eql(u8, x1.B, "foo"));
            try expect(x2.* == .C);
            try expect(x3.A == y);
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "switching on non exhaustive union" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        const E = enum(u8) {
            a,
            b,
            _,
        };
        const U = union(E) {
            a: i32,
            b: u32,
        };
        fn doTheTest() !void {
            var a = U{ .a = 2 };
            _ = &a;
            switch (a) {
                .a => |val| try expect(val == 2),
                .b => return error.Fail,
            }
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "containers with single-field enums" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        const A = union(enum) { f1 };
        const B = union(enum) { f1: void };
        const C = struct { a: A };
        const D = struct { a: B };

        fn doTheTest() !void {
            var array1 = [1]A{A{ .f1 = {} }};
            var array2 = [1]B{B{ .f1 = {} }};
            _ = .{ &array1, &array2 };
            try expect(array1[0] == .f1);
            try expect(array2[0] == .f1);

            var struct1 = C{ .a = A{ .f1 = {} } };
            var struct2 = D{ .a = B{ .f1 = {} } };
            _ = .{ &struct1, &struct2 };
            try expect(struct1.a == .f1);
            try expect(struct2.a == .f1);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@unionInit on union with tag but no fields" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        const Type = enum(u8) { no_op = 105 };

        const Data = union(Type) {
            no_op: void,

            pub fn decode(buf: []const u8) Data {
                _ = buf;
                return @unionInit(Data, "no_op", {});
            }
        };

        comptime {
            assert(@sizeOf(Data) == 1);
        }

        fn doTheTest() !void {
            var data: Data = .{ .no_op = {} };
            _ = &data;
            var o = Data.decode(&[_]u8{});
            _ = &o;
            try expectEqual(Type.no_op, o);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "union enum type gets a separate scope" {
    const S = struct {
        const U = union(enum) {
            a: u8,
            const foo = 1;
        };

        fn doTheTest() !void {
            try expect(!@hasDecl(Tag(U), "foo"));
        }
    };

    try S.doTheTest();
}

test "global variable struct contains union initialized to non-most-aligned field" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const T = struct {
        const U = union(enum) {
            a: i32,
            b: f64,
        };

        const S = struct {
            u: U,
        };

        var s: S = .{
            .u = .{
                .a = 3,
            },
        };
    };

    T.s.u.a += 1;
    try expect(T.s.u.a == 4);
}

test "union with no result loc initiated with a runtime value" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const U = union {
        a: u32,
        b: u32,
        fn foo(u: @This()) void {
            _ = u;
        }
    };
    var a: u32 = 1;
    _ = &a;
    U.foo(U{ .a = a });
}

test "union with a large struct field" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        a: [8]usize,
    };

    const U = union {
        s: S,
        b: u32,
        fn foo(_: @This()) void {}
    };
    var s: S = undefined;
    _ = &s;
    U.foo(U{ .s = s });
}

test "comptime equality of extern unions with same tag" {
    const S = struct {
        const U = extern union {
            a: i32,
            b: f32,
        };
        fn foo(comptime x: U) i32 {
            return x.a;
        }
    };
    const a = S.U{ .a = 1234 };
    const b = S.U{ .a = 1234 };
    try expect(S.foo(a) == S.foo(b));
}

test "union tag is set when initiated as a temporary value at runtime" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const U = union(enum) {
        a,
        b: u32,
        c,

        fn doTheTest(u: @This()) !void {
            try expect(u == .b);
        }
    };
    var b: u32 = 1;
    _ = &b;
    try (U{ .b = b }).doTheTest();
}

test "extern union most-aligned field is smaller" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const U = extern union {
        in6: extern struct {
            family: u16,
            port: u16,
            flowinfo: u32,
            addr: [20]u8,
        },
        un: [110]u8,
    };
    var a: ?U = .{ .un = [_]u8{0} ** 110 };
    _ = &a;
    try expect(a != null);
}

test "return an extern union from C calling convention" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const namespace = struct {
        const S = extern struct {
            x: c_int,
        };
        const U = extern union {
            l: c_long,
            d: f64,
            s: S,
        };

        fn bar(arg_u: U) callconv(.C) U {
            var u = arg_u;
            _ = &u;
            return u;
        }
    };

    var u: namespace.U = namespace.U{
        .l = @as(c_long, 42),
    };
    u = namespace.bar(namespace.U{
        .d = 4.0,
    });
    try expect(u.d == 4.0);
}

test "noreturn field in union" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const U = union(enum) {
        a: u32,
        b: noreturn,
        c: noreturn,
    };
    var a = U{ .a = 1 };
    var count: u32 = 0;
    if (a == .b) @compileError("bad");
    switch (a) {
        .a => count += 1,
        .b => |val| {
            _ = val;
            @compileError("bad");
        },
        .c => @compileError("bad"),
    }
    switch (a) {
        .a => count += 1,
        .b, .c => @compileError("bad"),
    }
    switch (a) {
        .a, .b, .c => {
            count += 1;
            try expect(a == .a);
        },
    }
    switch (a) {
        .a => count += 1,
        else => @compileError("bad"),
    }
    switch (a) {
        else => {
            count += 1;
            try expect(a == .a);
        },
    }
    switch (a) {
        .a => count += 1,
        .b, .c => |*val| {
            _ = val;
            @compileError("bad");
        },
    }
    try expect(count == 6);
}

test "@unionInit uses tag value instead of field index" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const E = enum(u8) {
        b = 255,
        a = 3,
    };
    const U = union(E) {
        b: isize,
        a: usize,
    };
    var i: isize = -1;
    _ = &i;
    var u = @unionInit(U, "b", i);
    {
        var a = u.b;
        _ = &a;
        try expect(a == i);
    }
    {
        var a = &u.b;
        _ = &a;
        try expect(a.* == i);
    }
    try expect(@intFromEnum(u) == 255);
}

test "union field ptr - zero sized payload" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const U = union {
        foo: void,
        bar: void,
        fn bar(_: *void) void {}
    };
    var u: U = .{ .foo = {} };
    U.bar(&u.foo);
}

test "union field ptr - zero sized field" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const U = union {
        foo: void,
        bar: u32,
        fn bar(_: *void) void {}
    };
    var u: U = .{ .foo = {} };
    U.bar(&u.foo);
}

test "packed union in packed struct" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = packed struct {
        nested: packed union {
            val: usize,
            foo: u32,
        },
        bar: u32,

        fn unpack(self: @This()) usize {
            return self.nested.foo;
        }
    };
    const a: S = .{ .nested = .{ .foo = 123 }, .bar = 5 };
    try expect(a.unpack() == 123);
}

test "Namespace-like union" {
    const DepType = enum {
        git,
        http,
        const DepType = @This();
        const Version = union(DepType) {
            git: Git,
            http: void,
            const Git = enum {
                branch,
                tag,
                commit,
                fn frozen(self: Git) bool {
                    return self == .tag;
                }
            };
        };
    };
    var a: DepType.Version.Git = .tag;
    try expect(a.frozen());
}

test "union int tag type is properly managed" {
    const Bar = union(enum(u2)) {
        x: bool,
        y: u8,
        z: u8,
    };
    try expect(@sizeOf(Bar) + 1 == 3);
}

test "no dependency loop when function pointer in union returns the union" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const U = union(enum) {
        const U = @This();
        a: u8,
        b: *const fn (x: U) void,
        c: *const fn (x: U) U,
        d: *const fn (x: u8) U,
        e: *const fn (x: *U) void,
        f: *const fn (x: *U) U,
        fn foo(x: u8) U {
            return .{ .a = x };
        }
    };
    var b: U = .{ .d = U.foo };
    try expect(b.d(2).a == 2);
}

test "union reassignment can use previous value" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const U = union {
        a: u32,
        b: u32,
    };
    var a = U{ .a = 32 };
    a = U{ .b = a.a };
    try expect(a.b == 32);
}

test "packed union with zero-bit field" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = packed struct {
        nested: packed union {
            zero: void,
            sized: u32,
        },
        bar: u32,

        fn doTest(self: @This()) !void {
            try expect(self.bar == 42);
        }
    };
    try S.doTest(.{ .nested = .{ .zero = {} }, .bar = 42 });
}

test "reinterpreting enum value inside packed union" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const U = packed union {
        tag: enum(u8) { a, b },
        val: u8,

        fn doTest() !void {
            var u: @This() = .{ .tag = .a };
            u.val += 1;
            try expect(u.tag == .b);
        }
    };
    try U.doTest();
    try comptime U.doTest();
}

test "access the tag of a global tagged union" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const U = union(enum) {
        a,
        b: u8,
        var u: @This() = .a;
    };
    try expect(U.u == .a);
}

test "coerce enum literal to union in result loc" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const U = union(enum) {
        a,
        b: u8,

        fn doTest(c: bool) !void {
            const u = if (c) .a else @This(){ .b = 0 };
            try expect(u == .a);
        }
    };
    try U.doTest(true);
    try comptime U.doTest(true);
}

test "defined-layout union field pointer has correct alignment" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest(comptime U: type) !void {
            var a: U = .{ .x = 123 };
            var b: U align(1) = .{ .x = 456 };
            var c: U align(64) = .{ .x = 789 };

            const ap = &a.x;
            const bp = &b.x;
            const cp = &c.x;

            comptime assert(@TypeOf(ap) == *u32);
            comptime assert(@TypeOf(bp) == *align(1) u32);
            comptime assert(@TypeOf(cp) == *align(64) u32);

            try expectEqual(@as(u32, 123), ap.*);
            try expectEqual(@as(u32, 456), bp.*);
            try expectEqual(@as(u32, 789), cp.*);
        }
    };

    const U1 = extern union { x: u32 };
    const U2 = packed union { x: u32 };

    try S.doTheTest(U1);
    try S.doTheTest(U2);
    try comptime S.doTheTest(U1);
    try comptime S.doTheTest(U2);
}

test "undefined-layout union field pointer has correct alignment" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest(comptime U: type) !void {
            var a: U = .{ .x = 123 };
            var b: U align(1) = .{ .x = 456 };
            var c: U align(64) = .{ .x = 789 };

            const ap = &a.x;
            const bp = &b.x;
            const cp = &c.x;

            comptime assert(@TypeOf(ap) == *u32);
            comptime assert(@TypeOf(bp) == *align(1) u32);
            comptime assert(@TypeOf(cp) == *u32); // undefined layout so does not inherit larger aligns

            try expectEqual(@as(u32, 123), ap.*);
            try expectEqual(@as(u32, 456), bp.*);
            try expectEqual(@as(u32, 789), cp.*);
        }
    };

    const U1 = union { x: u32 };
    const U2 = union(enum) { x: u32 };

    try S.doTheTest(U1);
    try S.doTheTest(U2);
    try comptime S.doTheTest(U1);
    try comptime S.doTheTest(U2);
}

test "packed union field pointer has correct alignment" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest; // TODO

    const U = packed union { x: u20 };
    const S = packed struct(u24) { a: u2, u: U, b: u2 };

    var a: S = undefined;
    var b: S align(1) = undefined;
    var c: S align(64) = undefined;

    const ap = &a.u.x;
    const bp = &b.u.x;
    const cp = &c.u.x;

    comptime assert(@TypeOf(ap) == *align(4:2:3) u20);
    comptime assert(@TypeOf(bp) == *align(1:2:3) u20);
    comptime assert(@TypeOf(cp) == *align(64:2:3) u20);

    a.u = .{ .x = 123 };
    b.u = .{ .x = 456 };
    c.u = .{ .x = 789 };

    try expectEqual(@as(u20, 123), ap.*);
    try expectEqual(@as(u20, 456), bp.*);
    try expectEqual(@as(u20, 789), cp.*);
}

test "union with 128 bit integer" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const ValueTag = enum { int, other };

    const Value3 = union(ValueTag) {
        int: i128,
        other: bool,
    };
    var values: [2]Value3 = undefined;
    values[0] = .{ .int = 3 };
    values[1] = .{ .int = 4 };

    var ok: usize = 0;

    for (values) |val| {
        switch (val) {
            .int => ok += 1,
            else => return error.TestFailed,
        }
    }
}

test "memset extern union" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const U = extern union {
        foo: u8,
        bar: u32,
    };

    const S = struct {
        fn doTheTest() !void {
            var u: U = undefined;
            @memset(std.mem.asBytes(&u), 0);
            try expectEqual(@as(u8, 0), u.foo);
            try expectEqual(@as(u32, 0), u.bar);
        }
    };

    try comptime S.doTheTest();
    try S.doTheTest();
}

test "memset packed union" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const U = packed union {
        a: u32,
        b: u8,
    };

    const S = struct {
        fn doTheTest() !void {
            var u: U = undefined;
            @memset(std.mem.asBytes(&u), 42);
            try expectEqual(@as(u32, 0x2a2a2a2a), u.a);
            try expectEqual(@as(u8, 0x2a), u.b);
        }
    };

    try comptime S.doTheTest();

    if (builtin.cpu.arch.isWasm()) return error.SkipZigTest; // TODO
    try S.doTheTest();
}

fn littleToNativeEndian(comptime T: type, v: T) T {
    return if (endian == .little) v else @byteSwap(v);
}

test "reinterpret extern union" {
    if (true) {
        // https://github.com/ziglang/zig/issues/19389
        return error.SkipZigTest;
    }

    const U = extern union {
        foo: u8,
        baz: u32 align(8),
        bar: u32,
    };

    const S = struct {
        fn doTheTest() !void {
            {
                // Undefined initialization
                const u = blk: {
                    var u: U = undefined;
                    @memset(std.mem.asBytes(&u), 0);
                    u.bar = 0xbbbbbbbb;
                    u.foo = 0x2a;
                    break :blk u;
                };

                try expectEqual(@as(u8, 0x2a), u.foo);
                try expectEqual(littleToNativeEndian(u32, 0xbbbbbb2a), u.bar);
                try expectEqual(littleToNativeEndian(u32, 0xbbbbbb2a), u.baz);
            }

            {
                // Union initialization
                var u: U = .{
                    .foo = 0x2a,
                };

                {
                    const expected, const mask = switch (endian) {
                        .little => .{ 0x2a, 0xff },
                        .big => .{ 0x2a000000, 0xff000000 },
                    };

                    try expectEqual(@as(u8, 0x2a), u.foo);
                    try expectEqual(@as(u32, expected), u.bar & mask);
                    try expectEqual(@as(u32, expected), u.baz & mask);
                }

                // Writing to a larger field
                u.baz = 0xbbbbbbbb;
                try expectEqual(@as(u8, 0xbb), u.foo);
                try expectEqual(@as(u32, 0xbbbbbbbb), u.bar);
                try expectEqual(@as(u32, 0xbbbbbbbb), u.baz);

                // Writing to the same field
                u.baz = 0xcccccccc;
                try expectEqual(@as(u8, 0xcc), u.foo);
                try expectEqual(@as(u32, 0xcccccccc), u.bar);
                try expectEqual(@as(u32, 0xcccccccc), u.baz);

                // Writing to a smaller field
                u.foo = 0xdd;
                try expectEqual(@as(u8, 0xdd), u.foo);
                try expectEqual(littleToNativeEndian(u32, 0xccccccdd), u.bar);
                try expectEqual(littleToNativeEndian(u32, 0xccccccdd), u.baz);
            }
        }
    };

    try comptime S.doTheTest();

    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest; // TODO
    try S.doTheTest();
}

test "reinterpret packed union" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const U = packed union {
        foo: u8,
        bar: u29,
        baz: u64,
        qux: u12,
    };

    const S = struct {
        fn doTheTest() !void {
            {
                const u = blk: {
                    var u: U = undefined;
                    @memset(std.mem.asBytes(&u), 0);
                    u.baz = 0xbbbbbbbb;
                    u.qux = 0xe2a;
                    break :blk u;
                };

                try expectEqual(@as(u8, 0x2a), u.foo);
                try expectEqual(@as(u12, 0xe2a), u.qux);

                // https://github.com/ziglang/zig/issues/17360
                if (@inComptime()) {
                    try expectEqual(@as(u29, 0x1bbbbe2a), u.bar);
                    try expectEqual(@as(u64, 0xbbbbbe2a), u.baz);
                }
            }

            {
                // Union initialization
                var u: U = .{ .baz = 0 }; // ensure all bits are defined
                u.qux = 0xe2a;
                try expectEqual(@as(u8, 0x2a), u.foo);
                try expectEqual(@as(u12, 0xe2a), u.qux);
                try expectEqual(@as(u29, 0xe2a), u.bar & 0xfff);
                try expectEqual(@as(u64, 0xe2a), u.baz & 0xfff);

                // Writing to a larger field
                u.baz = 0xbbbbbbbb;
                try expectEqual(@as(u8, 0xbb), u.foo);
                try expectEqual(@as(u12, 0xbbb), u.qux);
                try expectEqual(@as(u29, 0x1bbbbbbb), u.bar);
                try expectEqual(@as(u64, 0xbbbbbbbb), u.baz);

                // Writing to the same field
                u.baz = 0xcccccccc;
                try expectEqual(@as(u8, 0xcc), u.foo);
                try expectEqual(@as(u12, 0xccc), u.qux);
                try expectEqual(@as(u29, 0x0ccccccc), u.bar);
                try expectEqual(@as(u64, 0xcccccccc), u.baz);

                // Writing to a smaller field
                u.foo = 0xdd;
                try expectEqual(@as(u8, 0xdd), u.foo);
                try expectEqual(@as(u12, 0xcdd), u.qux);
                try expectEqual(@as(u29, 0x0cccccdd), u.bar);
                try expectEqual(@as(u64, 0xccccccdd), u.baz);
            }
        }
    };

    try comptime S.doTheTest();

    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.cpu.arch.isPPC()) return error.SkipZigTest; // TODO
    if (builtin.cpu.arch.isWasm()) return error.SkipZigTest; // TODO
    try S.doTheTest();
}

test "reinterpret packed union inside packed struct" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const U = packed union {
        a: u7,
        b: u1,
    };

    const V = packed struct {
        lo: U,
        hi: U,
    };

    const S = struct {
        fn doTheTest() !void {
            var v: V = undefined;
            @memset(std.mem.asBytes(&v), 0x55);
            try expectEqual(@as(u7, 0x55), v.lo.a);
            try expectEqual(@as(u1, 1), v.lo.b);
            try expectEqual(@as(u7, 0x2a), v.hi.a);
            try expectEqual(@as(u1, 0), v.hi.b);

            v.lo.b = 0;
            try expectEqual(@as(u7, 0x54), v.lo.a);
            try expectEqual(@as(u1, 0), v.lo.b);
            v.hi.b = 1;
            try expectEqual(@as(u7, 0x2b), v.hi.a);
            try expectEqual(@as(u1, 1), v.hi.b);
        }
    };

    try comptime S.doTheTest();

    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    try S.doTheTest();
}

test "inner struct initializer uses union layout" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const namespace = struct {
        const U = union {
            a: struct {
                x: u32 = @alignOf(U) + 1,
            },
            b: struct {
                y: u16 = @sizeOf(U) + 2,
            },
        };
    };

    {
        const u: namespace.U = .{ .a = .{} };
        try expectEqual(4, @alignOf(namespace.U));
        try expectEqual(@as(usize, 5), u.a.x);
    }

    {
        const u: namespace.U = .{ .b = .{} };
        try expectEqual(@as(usize, @sizeOf(namespace.U) + 2), u.b.y);
    }
}

test "inner struct initializer uses packed union layout" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const namespace = struct {
        const U = packed union {
            a: packed struct {
                x: u32 = @alignOf(U) + 1,
            },
            b: packed struct {
                y: u16 = @sizeOf(U) + 2,
            },
        };
    };

    {
        const u: namespace.U = .{ .a = .{} };
        try expectEqual(4, @alignOf(namespace.U));
        try expectEqual(@as(usize, 5), u.a.x);
    }

    {
        const u: namespace.U = .{ .b = .{} };
        try expectEqual(@as(usize, @sizeOf(namespace.U) + 2), u.b.y);
    }
}

test "extern union initialized via reintepreted struct field initializer" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const bytes = [_]u8{ 0xaa, 0xbb, 0xcc, 0xdd };

    const U = extern union {
        a: u32,
        b: u8,
    };

    const S = extern struct {
        u: U = std.mem.bytesAsValue(U, &bytes).*,
    };

    const s: S = .{};
    try expect(s.u.a == littleToNativeEndian(u32, 0xddccbbaa));
    try expect(s.u.b == 0xaa);
}

test "packed union initialized via reintepreted struct field initializer" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const bytes = [_]u8{ 0xaa, 0xbb, 0xcc, 0xdd };

    const U = packed union {
        a: u32,
        b: u8,
    };

    const S = packed struct {
        u: U = std.mem.bytesAsValue(U, &bytes).*,
    };

    var s: S = .{};
    _ = &s;
    try expect(s.u.a == littleToNativeEndian(u32, 0xddccbbaa));
    try expect(s.u.b == if (endian == .little) 0xaa else 0xdd);
}

test "store of comptime reinterpreted memory to extern union" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const bytes = [_]u8{ 0xaa, 0xbb, 0xcc, 0xdd };

    const U = extern union {
        a: u32,
        b: u8,
    };

    const reinterpreted = comptime b: {
        var u: U = undefined;
        u = std.mem.bytesAsValue(U, &bytes).*;
        break :b u;
    };

    var u: U = reinterpreted;
    _ = &u;
    try expect(u.a == littleToNativeEndian(u32, 0xddccbbaa));
    try expect(u.b == 0xaa);
}

test "store of comptime reinterpreted memory to packed union" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const bytes = [_]u8{ 0xaa, 0xbb, 0xcc, 0xdd };

    const U = packed union {
        a: u32,
        b: u8,
    };

    const reinterpreted = comptime b: {
        var u: U = undefined;
        u = std.mem.bytesAsValue(U, &bytes).*;
        break :b u;
    };

    var u: U = reinterpreted;
    _ = &u;
    try expect(u.a == littleToNativeEndian(u32, 0xddccbbaa));
    try expect(u.b == if (endian == .little) 0xaa else 0xdd);
}

test "union field is a pointer to an aligned version of itself" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const E = union {
        next: *align(1) @This(),
    };
    var e: E = undefined;
    e = .{ .next = &e };

    try expect(&e == e.next);
}

test "pass register-sized field as non-register-sized union" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn taggedUnion(u: union(enum) { x: usize, y: [2]usize }) !void {
            try expectEqual(@as(usize, 42), u.x);
        }

        fn untaggedUnion(u: union { x: usize, y: [2]usize }) !void {
            try expectEqual(@as(usize, 42), u.x);
        }

        fn externUnion(u: extern union { x: usize, y: [2]usize }) !void {
            try expectEqual(@as(usize, 42), u.x);
        }
    };

    var x: usize = 42;
    _ = &x;
    try S.taggedUnion(.{ .x = x });
    try S.untaggedUnion(.{ .x = x });
    try S.externUnion(.{ .x = x });
}

test "circular dependency through pointer field of a union" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        const UnionInner = extern struct {
            outer: UnionOuter = std.mem.zeroes(UnionOuter),
        };

        const UnionMiddle = extern union {
            outer: ?*UnionOuter,
            inner: ?*UnionInner,
        };

        const UnionOuter = extern struct {
            u: UnionMiddle = std.mem.zeroes(UnionMiddle),
        };
    };
    var outer: S.UnionOuter = .{};
    _ = &outer;
    try expect(outer.u.outer == null);
    try expect(outer.u.inner == null);
}

test "pass nested union with rls" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const Union = union(enum) {
        a: u32,
        b: union(enum) {
            c: u7,
            d: u3,
        },

        fn getC(u: @This()) u7 {
            return u.b.c;
        }
    };

    var c: u7 = 32;
    _ = &c;
    try expectEqual(@as(u7, 32), Union.getC(.{ .b = .{ .c = c } }));
}

test "runtime union init, most-aligned field != largest" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const U = union(enum) {
        x: u128,
        y: [17]u8,

        fn foo(val: @This()) !void {
            try expect(val.x == 1);
        }
    };
    var x: u8 = 1;
    _ = &x;
    try U.foo(.{ .x = x });

    const val: U = @unionInit(U, "x", x);
    try expect(val.x == 1);

    const val2: U = .{ .x = x };
    try expect(val2.x == 1);
}

test "copied union field doesn't alias source" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const U = union(enum) {
        array: [10]u32,
        other: u32,
    };

    var x = U{ .array = undefined };

    x.array[1] = 0;
    const a = x.array;
    x.array[1] = 15;

    try expect(a[1] == 0);
}

test "create union(enum) from other union(enum)" {
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const string = "hello world";
    const TempRef = struct {
        index: usize,
        is_weak: bool,
    };
    const BuiltinEnum = struct {
        name: []const u8,
    };
    const ParamType = union(enum) {
        boolean,
        buffer,
        one_of: BuiltinEnum,
    };
    const EnumLiteral = struct {
        label: []const u8,
    };

    const ExpressionResult = union(enum) {
        temp_buffer: TempRef,
        literal_boolean: bool,
        literal_enum_value: []const u8,

        fn commitCalleeParam(result: @This(), callee_param_type: ParamType) @This() {
            switch (callee_param_type) {
                .boolean => return result,
                .buffer => return .{
                    .temp_buffer = .{ .index = 0, .is_weak = false },
                },
                .one_of => return result,
            }
        }
    };
    const Expression = union(enum) {
        literal_boolean: bool,
        literal_enum_value: EnumLiteral,

        fn genExpression(expr: @This()) !ExpressionResult {
            switch (expr) {
                .literal_boolean => |value| return .{
                    .literal_boolean = value,
                },
                .literal_enum_value => |v| {
                    try std.testing.expectEqualStrings(string, v.label);
                    const result: ExpressionResult = .{
                        .literal_enum_value = v.label,
                    };
                    switch (result) {
                        .literal_enum_value => |w| {
                            try std.testing.expectEqualStrings(string, w);
                        },
                        else => {},
                    }
                    return result;
                },
            }
        }
    };
    const CallArg = struct {
        value: Expression,
    };

    var param: ParamType = .{
        .one_of = .{ .name = "name" },
    };
    _ = &param;
    var arg: CallArg = .{
        .value = .{
            .literal_enum_value = .{
                .label = string,
            },
        },
    };
    _ = &arg;

    const result = try arg.value.genExpression();
    switch (result) {
        .literal_enum_value => |w| {
            try std.testing.expectEqualStrings(string, w);
        },
        else => {},
    }

    const derp = result.commitCalleeParam(param);
    switch (derp) {
        .literal_enum_value => |w| {
            try std.testing.expectEqualStrings(string, w);
        },
        else => {},
    }
}

test "matching captures causes union equivalence" {
    const S = struct {
        fn SignedUnsigned(comptime I: type) type {
            const bits = @typeInfo(I).Int.bits;
            return union {
                u: @Type(.{ .Int = .{
                    .signedness = .unsigned,
                    .bits = bits,
                } }),
                i: @Type(.{ .Int = .{
                    .signedness = .signed,
                    .bits = bits,
                } }),
            };
        }
    };

    comptime assert(S.SignedUnsigned(u8) == S.SignedUnsigned(i8));
    comptime assert(S.SignedUnsigned(u16) == S.SignedUnsigned(i16));
    comptime assert(S.SignedUnsigned(u8) != S.SignedUnsigned(u16));

    const a: S.SignedUnsigned(u8) = .{ .u = 10 };
    const b: S.SignedUnsigned(i8) = .{ .u = 10 };
    comptime assert(@TypeOf(a) == @TypeOf(b));
    try expect(a.u == b.u);
}

test "signed enum tag with negative value" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const Enum = enum(i8) {
        a = -1,
    };

    const Union = union(Enum) {
        a: i32,
    };

    var i: i32 = 0;
    i = i;
    const e = Union{ .a = i };

    try expect(e.a == i);
}
