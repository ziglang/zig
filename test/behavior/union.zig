const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const Tag = std.meta.Tag;

const Foo = union {
    float: f64,
    int: i32,
};

test "basic unions" {
    var foo = Foo{ .int = 1 };
    try expect(foo.int == 1);
    foo = Foo{ .float = 12.34 };
    try expect(foo.float == 12.34);
}

test "init union with runtime value" {
    var foo: Foo = undefined;

    setFloat(&foo, 12.34);
    try expect(foo.float == 12.34);

    setInt(&foo, 42);
    try expect(foo.int == 42);
}

fn setFloat(foo: *Foo, x: f64) void {
    foo.* = Foo{ .float = x };
}

fn setInt(foo: *Foo, x: i32) void {
    foo.* = Foo{ .int = x };
}

test "comptime union field access" {
    comptime {
        var foo = Foo{ .int = 0 };
        try expect(foo.int == 0);

        foo = Foo{ .float = 42.42 };
        try expect(foo.float == 42.42);
    }
}

const FooExtern = extern union {
    float: f64,
    int: i32,
};

test "basic extern unions" {
    var foo = FooExtern{ .int = 1 };
    try expect(foo.int == 1);
    foo.float = 12.34;
    try expect(foo.float == 12.34);
}

const ExternPtrOrInt = extern union {
    ptr: *u8,
    int: u64,
};
test "extern union size" {
    comptime try expect(@sizeOf(ExternPtrOrInt) == 8);
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

    comptime try expect(Bar.A == u8);
}

test "constant tagged union with payload" {
    var empty = TaggedUnionWithPayload{ .Empty = {} };
    var full = TaggedUnionWithPayload{ .Full = 13 };
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
    try doTest();
    comptime try doTest();
}

test "packed union generates correctly aligned LLVM type" {
    if (builtin.zig_backend == .stage1) return error.SkipZigTest;

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
    try expect(x == .A);
    try expect(x != .B);
    try expect(x != .C);
    try expect((x == .B) == false);
    try expect((x == .C) == false);
    try expect((x != .A) == false);
}

test "comparison between union and enum literal" {
    try testComparison();
    comptime try testComparison();
}

const TheTag = enum { A, B, C };
const TheUnion = union(TheTag) {
    A: i32,
    B: i32,
    C: i32,
};
test "cast union to tag type of union" {
    try testCastUnionToTag();
    comptime try testCastUnionToTag();
}

fn testCastUnionToTag() !void {
    var u = TheUnion{ .B = 1234 };
    try expect(@as(TheTag, u) == TheTag.B);
}

test "union field access gives the enum values" {
    try expect(TheUnion.A == TheTag.A);
    try expect(TheUnion.B == TheTag.B);
    try expect(TheUnion.C == TheTag.C);
}

test "cast tag type of union to union" {
    var x: Value2 = Letter2.B;
    try expect(@as(Letter2, x) == Letter2.B);
}
const Letter2 = enum { A, B, C };
const Value2 = union(Letter2) {
    A: i32,
    B,
    C,
};

test "implicit cast union to its tag type" {
    var x: Value2 = Letter2.B;
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
    var x = MultipleChoice.C;
    try expect(x == MultipleChoice.C);
    try expect(@enumToInt(@as(Tag(MultipleChoice), x)) == 60);
}

const PackedPtrOrInt = packed union {
    ptr: *u8,
    int: u64,
};
test "packed union size" {
    comptime try expect(@sizeOf(PackedPtrOrInt) == 8);
}

const ZeroBits = union {
    OnlyField: void,
};
test "union with only 1 field which is void should be zero bits" {
    comptime try expect(@sizeOf(ZeroBits) == 0);
}

test "tagged union initialization with runtime void" {
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
    const a = UnionEnumNoPayloads{ .B = {} };
    switch (a) {
        Tag(UnionEnumNoPayloads).A => @panic("wrong"),
        Tag(UnionEnumNoPayloads).B => {},
    }
}

test "union with only 1 field casted to its enum type" {
    const Literal = union(enum) {
        Number: f64,
        Bool: bool,
    };

    const Expr = union(enum) {
        Literal: Literal,
    };

    var e = Expr{ .Literal = Literal{ .Bool = true } };
    const ExprTag = Tag(Expr);
    comptime try expect(Tag(ExprTag) == u0);
    var t = @as(ExprTag, e);
    try expect(t == Expr.Literal);
}

test "union with one member defaults to u0 tag type" {
    const U0 = union(enum) {
        X: u32,
    };
    comptime try expect(Tag(Tag(U0)) == u0);
}

const Foo1 = union(enum) {
    f: struct {
        x: usize,
    },
};
var glbl: Foo1 = undefined;

test "global union with single field is correctly initialized" {
    glbl = Foo1{
        .f = @typeInfo(Foo1).Union.fields[0].field_type{ .x = 123 },
    };
    try expect(glbl.f.x == 123);
}

pub const FooUnion = union(enum) {
    U0: usize,
    U1: u8,
};

var glbl_array: [2]FooUnion = undefined;

test "initialize global array of union" {
    glbl_array[1] = FooUnion{ .U1 = 2 };
    glbl_array[0] = FooUnion{ .U0 = 1 };
    try expect(glbl_array[0].U0 == 1);
    try expect(glbl_array[1].U1 == 2);
}

test "update the tag value for zero-sized unions" {
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
    const U = union(enum) {
        A: u24,
    };

    var v = U{ .A = 532 };
    try expect(v.A == 532);
}

test "runtime tag name with single field" {
    const U = union(enum) {
        A: i32,
    };

    var v = U{ .A = 42 };
    try expect(std.mem.eql(u8, @tagName(v), "A"));
}

test "method call on an empty union" {
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
    comptime try S.doTheTest();
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
    switch (returnAnInt(13)) {
        TaggedFoo.One => |value| try expect(value == 13),
        else => unreachable,
    }
}

fn returnAnInt(x: i32) TaggedFoo {
    return TaggedFoo{ .One = x };
}

test "tagged union with all void fields but a meaningful tag" {
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
    // TODO enable the test at comptime too
    //comptime try S.doTheTest();
}
