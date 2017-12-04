const assert = @import("std").debug.assert;

const Value = union(enum) {
    Int: u64,
    Array: [9]u8,
};

const Agg = struct {
    val1: Value,
    val2: Value,
};

const v1 = Value { .Int = 1234 };
const v2 = Value { .Array = []u8{3} ** 9 };

const err = (%Agg)(Agg {
    .val1 = v1,
    .val2 = v2,
});

const array = []Value { v1, v2, v1, v2};


test "unions embedded in aggregate types" {
    switch (array[1]) {
        Value.Array => |arr| assert(arr[4] == 3),
        else => unreachable,
    }
    switch((%%err).val1) {
        Value.Int => |x| assert(x == 1234),
        else => unreachable,
    }
}


const Foo = union {
    float: f64,
    int: i32,
};

test "basic unions" {
    var foo = Foo { .int = 1 };
    assert(foo.int == 1);
    foo = Foo {.float = 12.34};
    assert(foo.float == 12.34);
}

test "init union with runtime value" {
    var foo: Foo = undefined;

    setFloat(&foo, 12.34);
    assert(foo.float == 12.34);

    setInt(&foo, 42);
    assert(foo.int == 42);
}

fn setFloat(foo: &Foo, x: f64) {
    *foo = Foo { .float = x };
}

fn setInt(foo: &Foo, x: i32) {
    *foo = Foo { .int = x };
}

const FooExtern = extern union {
    float: f64,
    int: i32,
};

test "basic extern unions" {
    var foo = FooExtern { .int = 1 };
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

fn doTest() {
    assert(bar(Payload {.A = 1234}) == -10);
}

fn bar(value: &const Payload) -> i32 {
    assert(Letter(*value) == Letter.A);
    return switch (*value) {
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
    assert(u32(@TagType(MultipleChoice)(x)) == 60);
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
    testEnumWithSpecifiedAndUnspecifiedTagValues(MultipleChoice2 {.C = 123});
    comptime testEnumWithSpecifiedAndUnspecifiedTagValues(MultipleChoice2 { .C = 123} );
}

fn testEnumWithSpecifiedAndUnspecifiedTagValues(x: &const MultipleChoice2) {
    assert(u32(@TagType(MultipleChoice2)(*x)) == 60);
    assert(1123 == switch (*x) {
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
    ptr: &u8,
    int: u64
};
test "extern union size" {
    comptime assert(@sizeOf(ExternPtrOrInt) == 8);
}

const PackedPtrOrInt = packed union {
    ptr: &u8,
    int: u64
};
test "extern union size" {
    comptime assert(@sizeOf(PackedPtrOrInt) == 8);
}
