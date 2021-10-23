const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const Tag = std.meta.Tag;

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

test "union(enum(u32)) with specified and unspecified tag values" {
    comptime try expect(Tag(Tag(MultipleChoice2)) == u32);
    try testEnumWithSpecifiedAndUnspecifiedTagValues(MultipleChoice2{ .C = 123 });
    comptime try testEnumWithSpecifiedAndUnspecifiedTagValues(MultipleChoice2{ .C = 123 });
}

fn testEnumWithSpecifiedAndUnspecifiedTagValues(x: MultipleChoice2) !void {
    try expect(@enumToInt(@as(Tag(MultipleChoice2), x)) == 60);
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

const TheTag = enum { A, B, C };
const TheUnion = union(TheTag) {
    A: i32,
    B: i32,
    C: i32,
};
test "union field access gives the enum values" {
    try expect(TheUnion.A == TheTag.A);
    try expect(TheUnion.B == TheTag.B);
    try expect(TheUnion.C == TheTag.C);
}

test "cast union to tag type of union" {
    try testCastUnionToTag();
    comptime try testCastUnionToTag();
}

fn testCastUnionToTag() !void {
    var u = TheUnion{ .B = 1234 };
    try expect(@as(TheTag, u) == TheTag.B);
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

test "switch on union with only 1 field" {
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

test "access a member of tagged union with conflicting enum tag name" {
    const Bar = union(enum) {
        A: A,
        B: B,

        const A = u8;
        const B = void;
    };

    comptime try expect(Bar.A == u8);
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

test "union with only 1 field casted to its enum type which has enum value specified" {
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
    comptime try expect(Tag(ExprTag) == comptime_int);
    var t = @as(ExprTag, e);
    try expect(t == Expr.Literal);
    try expect(@enumToInt(t) == 33);
    comptime try expect(@enumToInt(t) == 33);
}

test "@enumToInt works on unions" {
    const Bar = union(enum) {
        A: bool,
        B: u8,
        C,
    };

    const a = Bar{ .A = true };
    var b = Bar{ .B = undefined };
    var c = Bar.C;
    try expect(@enumToInt(a) == 0);
    try expect(@enumToInt(b) == 1);
    try expect(@enumToInt(c) == 2);
}

const Attribute = union(enum) {
    A: bool,
    B: u8,
};

fn setAttribute(attr: Attribute) void {
    _ = attr;
}

fn Setter(attr: Attribute) type {
    return struct {
        fn set() void {
            setAttribute(attr);
        }
    };
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

test "return union init with void payload" {
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
    comptime try S.entry();
}

test "@unionInit can modify a union type" {
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
    const UnionInitEnum = union(enum) {
        Boolean: bool,
        Byte: u8,
    };

    var value: UnionInitEnum = undefined;
    var value_ptr = &value;

    value_ptr.* = @unionInit(UnionInitEnum, "Boolean", true);
    try expect(value.Boolean == true);

    value_ptr.* = @unionInit(UnionInitEnum, "Byte", 2);
    try expect(value.Byte == 2);
}

test "union no tag with struct member" {
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

test "packed union generates correctly aligned LLVM type" {
    const U = packed union {
        f1: fn () error{TestUnexpectedResult}!void,
        f2: u32,
    };
    var foo = [_]U{
        U{ .f1 = doTest },
        U{ .f2 = 0 },
    };
    try foo[0].f1();
}

test "union with one member defaults to u0 tag type" {
    const U0 = union(enum) {
        X: u32,
    };
    comptime try expect(Tag(Tag(U0)) == u0);
}

test "union with comptime_int tag" {
    const Union = union(enum(comptime_int)) {
        X: u32,
        Y: u16,
        Z: u8,
    };
    comptime try expect(Tag(Tag(Union)) == comptime_int);
}

test "extern union doesn't trigger field check at comptime" {
    const U = extern union {
        x: u32,
        y: u8,
    };

    const x = U{ .x = 0x55AAAA55 };
    comptime try expect(x.y == 0x55);
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

test "anonymous union literal syntax" {
    const S = struct {
        const Number = union {
            int: i32,
            float: f64,
        };

        fn doTheTest() !void {
            var i: Number = .{ .int = 42 };
            var f = makeNumber();
            try expect(i.int == 42);
            try expect(f.float == 12.34);
        }

        fn makeNumber() Number {
            return .{ .float = 12.34 };
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
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

test "function call result coerces from tagged union to the tag" {
    const S = struct {
        const Arch = union(enum) {
            One,
            Two: usize,
        };

        const ArchTag = Tag(Arch);

        fn doTheTest() !void {
            var x: ArchTag = getArch1();
            try expect(x == .One);

            var y: ArchTag = getArch2();
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
    comptime try S.doTheTest();
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

test "cast from anonymous struct to union" {
    const S = struct {
        const U = union(enum) {
            A: u32,
            B: []const u8,
            C: void,
        };
        fn doTheTest() !void {
            var y: u32 = 42;
            const t0 = .{ .A = 123 };
            const t1 = .{ .B = "foo" };
            const t2 = .{ .C = {} };
            const t3 = .{ .A = y };
            const x0: U = t0;
            var x1: U = t1;
            const x2: U = t2;
            var x3: U = t3;
            try expect(x0.A == 123);
            try expect(std.mem.eql(u8, x1.B, "foo"));
            try expect(x2 == .C);
            try expect(x3.A == y);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "cast from pointer to anonymous struct to pointer to union" {
    const S = struct {
        const U = union(enum) {
            A: u32,
            B: []const u8,
            C: void,
        };
        fn doTheTest() !void {
            var y: u32 = 42;
            const t0 = &.{ .A = 123 };
            const t1 = &.{ .B = "foo" };
            const t2 = &.{ .C = {} };
            const t3 = &.{ .A = y };
            const x0: *const U = t0;
            var x1: *const U = t1;
            const x2: *const U = t2;
            var x3: *const U = t3;
            try expect(x0.A == 123);
            try expect(std.mem.eql(u8, x1.B, "foo"));
            try expect(x2.* == .C);
            try expect(x3.A == y);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
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

test "switching on non exhaustive union" {
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
            switch (a) {
                .a => |val| try expect(val == 2),
                .b => unreachable,
            }
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "containers with single-field enums" {
    const S = struct {
        const A = union(enum) { f1 };
        const B = union(enum) { f1: void };
        const C = struct { a: A };
        const D = struct { a: B };

        fn doTheTest() !void {
            var array1 = [1]A{A{ .f1 = {} }};
            var array2 = [1]B{B{ .f1 = {} }};
            try expect(array1[0] == .f1);
            try expect(array2[0] == .f1);

            var struct1 = C{ .a = A{ .f1 = {} } };
            var struct2 = D{ .a = B{ .f1 = {} } };
            try expect(struct1.a == .f1);
            try expect(struct2.a == .f1);
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
}

test "@unionInit on union w/ tag but no fields" {
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
            std.debug.assert(@sizeOf(Data) != 0);
        }

        fn doTheTest() !void {
            var data: Data = .{ .no_op = .{} };
            _ = data;
            var o = Data.decode(&[_]u8{});
            try expectEqual(Type.no_op, o);
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
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

test "anytype union field: issue #9233" {
    const Quux = union(enum) { bar: anytype };
    _ = Quux;
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
