const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const Tag = std.meta.Tag;

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
