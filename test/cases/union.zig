const assert = @import("std").debug.assert;

const Value = union(enum) {
    Int: u64,
    Array: [9]u8,
};

const Agg = struct {
    val1: Value,
    val2: Value,
};

const v1 = Value{ .Int = 1234 };
const v2 = Value{ .Array = []u8{3} ** 9 };

const err = (error!Agg)(Agg{
    .val1 = v1,
    .val2 = v2,
});

const array = []Value{
    v1,
    v2,
    v1,
    v2,
};

test "unions embedded in aggregate types" {
    switch (array[1]) {
        Value.Array => |arr| assert(arr[4] == 3),
        else => unreachable,
    }
    switch ((err catch unreachable).val1) {
        Value.Int => |x| assert(x == 1234),
        else => unreachable,
    }
}

const Foo = union {
    float: f64,
    int: i32,
};

test "basic unions" {
    var foo = Foo{ .int = 1 };
    assert(foo.int == 1);
    foo = Foo{ .float = 12.34 };
    assert(foo.float == 12.34);
}

test "comptime union field access" {
    comptime {
        var foo = Foo{ .int = 0 };
        assert(foo.int == 0);

        foo = Foo{ .float = 42.42 };
        assert(foo.float == 42.42);
    }
}

test "init union with runtime value" {
    var foo: Foo = undefined;

    setFloat(&foo, 12.34);
    assert(foo.float == 12.34);

    setInt(&foo, 42);
    assert(foo.int == 42);
}

fn setFloat(foo: *Foo, x: f64) void {
    foo.* = Foo{ .float = x };
}

fn setInt(foo: *Foo, x: i32) void {
    foo.* = Foo{ .int = x };
}

const FooExtern = extern union {
    float: f64,
    int: i32,
};

test "basic extern unions" {
    var foo = FooExtern{ .int = 1 };
    assert(foo.int == 1);
    foo.float = 12.34;
    assert(foo.float == 12.34);
}

const Letter = enum {
    A,
    B,
    C,
};
const Payload = union(Letter) {
    A: i32,
    B: f64,
    C: bool,
};

test "union with specified enum tag" {
    doTest();
    comptime doTest();
}

fn doTest() void {
    assert(bar(Payload{ .A = 1234 }) == -10);
}

fn bar(value: *const Payload) i32 {
    assert(Letter(value.*) == Letter.A);
    return switch (value.*) {
        Payload.A => |x| return x - 1244,
        Payload.B => |x| if (x == 12.34) i32(20) else 21,
        Payload.C => |x| if (x) i32(30) else 31,
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
    assert(x == MultipleChoice.C);
    assert(@enumToInt(@TagType(MultipleChoice)(x)) == 60);
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
    comptime assert(@TagType(@TagType(MultipleChoice2)) == u32);
    testEnumWithSpecifiedAndUnspecifiedTagValues(MultipleChoice2{ .C = 123 });
    comptime testEnumWithSpecifiedAndUnspecifiedTagValues(MultipleChoice2{ .C = 123 });
}

fn testEnumWithSpecifiedAndUnspecifiedTagValues(x: *const MultipleChoice2) void {
    assert(@enumToInt(@TagType(MultipleChoice2)(x.*)) == 60);
    assert(1123 == switch (x.*) {
        MultipleChoice2.A => 1,
        MultipleChoice2.B => 2,
        MultipleChoice2.C => |v| i32(1000) + v,
        MultipleChoice2.D => 4,
        MultipleChoice2.Unspecified1 => 5,
        MultipleChoice2.Unspecified2 => 6,
        MultipleChoice2.Unspecified3 => 7,
        MultipleChoice2.Unspecified4 => 8,
        MultipleChoice2.Unspecified5 => 9,
    });
}

const ExternPtrOrInt = extern union {
    ptr: *u8,
    int: u64,
};
test "extern union size" {
    comptime assert(@sizeOf(ExternPtrOrInt) == 8);
}

const PackedPtrOrInt = packed union {
    ptr: *u8,
    int: u64,
};
test "extern union size" {
    comptime assert(@sizeOf(PackedPtrOrInt) == 8);
}

const ZeroBits = union {
    OnlyField: void,
};
test "union with only 1 field which is void should be zero bits" {
    comptime assert(@sizeOf(ZeroBits) == 0);
}

const TheTag = enum {
    A,
    B,
    C,
};
const TheUnion = union(TheTag) {
    A: i32,
    B: i32,
    C: i32,
};
test "union field access gives the enum values" {
    assert(TheUnion.A == TheTag.A);
    assert(TheUnion.B == TheTag.B);
    assert(TheUnion.C == TheTag.C);
}

test "cast union to tag type of union" {
    testCastUnionToTagType(TheUnion{ .B = 1234 });
    comptime testCastUnionToTagType(TheUnion{ .B = 1234 });
}

fn testCastUnionToTagType(x: *const TheUnion) void {
    assert(TheTag(x.*) == TheTag.B);
}

test "cast tag type of union to union" {
    var x: Value2 = Letter2.B;
    assert(Letter2(x) == Letter2.B);
}
const Letter2 = enum {
    A,
    B,
    C,
};
const Value2 = union(Letter2) {
    A: i32,
    B,
    C,
};

test "implicit cast union to its tag type" {
    var x: Value2 = Letter2.B;
    assert(x == Letter2.B);
    giveMeLetterB(x);
}
fn giveMeLetterB(x: Letter2) void {
    assert(x == Value2.B);
}

test "implicit cast from @EnumTagType(TheUnion) to &const TheUnion" {
    assertIsTheUnion2Item1(TheUnion2.Item1);
}

const TheUnion2 = union(enum) {
    Item1,
    Item2: i32,
};

fn assertIsTheUnion2Item1(value: *const TheUnion2) void {
    assert(value.* == TheUnion2.Item1);
}

pub const PackThis = union(enum) {
    Invalid: bool,
    StringLiteral: u2,
};

test "constant packed union" {
    testConstPackedUnion([]PackThis{PackThis{ .StringLiteral = 1 }});
}

fn testConstPackedUnion(expected_tokens: []const PackThis) void {
    assert(expected_tokens[0].StringLiteral == 1);
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
                    assert(x == 1234);
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

    comptime assert(Bar.A == u8);
}
