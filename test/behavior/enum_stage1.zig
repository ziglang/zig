const expect = @import("std").testing.expect;
const mem = @import("std").mem;
const Tag = @import("std").meta.Tag;

const Small2 = enum(u2) { One, Two };

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

test "enum literal in array literal" {
    const Items = enum { one, two };
    const array = [_]Items{ .one, .two };

    try expect(array[0] == .one);
    try expect(array[1] == .two);
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

const Bar = enum { A, B, C, D };

test "enum literal casting to error union with payload enum" {
    var bar: error{B}!Bar = undefined;
    bar = .B; // should never cast to the error set

    try expect((try bar) == Bar.B);
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
