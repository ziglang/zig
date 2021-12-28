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
