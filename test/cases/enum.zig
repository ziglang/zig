const assert = @import("std").debug.assert;
const mem = @import("std").mem;

test "enum type" {
    const foo1 = Foo.One {13};
    const foo2 = Foo.Two { Point { .x = 1234, .y = 5678, }};
    const bar = Bar.B;

    assert(bar == Bar.B);
    assert(@memberCount(Foo) == 3);
    assert(@memberCount(Bar) == 4);
    assert(@sizeOf(Foo) == @sizeOf(FooNoVoid));
    assert(@sizeOf(Bar) == 1);
}

test "enum as return value" {
    switch (returnAnInt(13)) {
        Foo.One => |value| assert(value == 13),
        else => unreachable,
    }
}

const Point = struct {
    x: u64,
    y: u64,
};
const Foo = enum {
    One: i32,
    Two: Point,
    Three: void,
};
const FooNoVoid = enum {
    One: i32,
    Two: Point,
};
const Bar = enum {
    A,
    B,
    C,
    D,
};

fn returnAnInt(x: i32) -> Foo {
    Foo.One { x }
}


test "constant enum with payload" {
    var empty = AnEnumWithPayload.Empty;
    var full = AnEnumWithPayload.Full {13};
    shouldBeEmpty(empty);
    shouldBeNotEmpty(full);
}

fn shouldBeEmpty(x: &const AnEnumWithPayload) {
    switch (*x) {
        AnEnumWithPayload.Empty => {},
        else => unreachable,
    }
}

fn shouldBeNotEmpty(x: &const AnEnumWithPayload) {
    switch (*x) {
        AnEnumWithPayload.Empty => unreachable,
        else => {},
    }
}

const AnEnumWithPayload = enum {
    Empty,
    Full: i32,
};



const Number = enum {
    Zero,
    One,
    Two,
    Three,
    Four,
};

test "enum to int" {
    shouldEqual(Number.Zero, 0);
    shouldEqual(Number.One, 1);
    shouldEqual(Number.Two, 2);
    shouldEqual(Number.Three, 3);
    shouldEqual(Number.Four, 4);
}

fn shouldEqual(n: Number, expected: usize) {
    assert(usize(n) == expected);
}


test "int to enum" {
    testIntToEnumEval(3);
}
fn testIntToEnumEval(x: i32) {
    assert(IntToEnumNumber(x) == IntToEnumNumber.Three);
}
const IntToEnumNumber = enum {
    Zero,
    One,
    Two,
    Three,
    Four,
};


test "@enumTagName" {
    assert(mem.eql(u8, testEnumTagNameBare(BareNumber.Three), "Three"));
    comptime assert(mem.eql(u8, testEnumTagNameBare(BareNumber.Three), "Three"));
}

fn testEnumTagNameBare(n: BareNumber) -> []const u8 {
    return @enumTagName(n);
}

const BareNumber = enum {
    One,
    Two,
    Three,
};


test "enum alignment" {
    comptime {
        assert(@alignOf(AlignTestEnum) >= @alignOf([9]u8));
        assert(@alignOf(AlignTestEnum) >= @alignOf(u64));
    }
}

const AlignTestEnum = enum {
    A: [9]u8,
    B: u64,
};
