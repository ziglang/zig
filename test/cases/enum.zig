const assertOrPanic = @import("std").debug.assertOrPanic;
const mem = @import("std").mem;

const MultipleChoice = enum(u32) {
    A = 20,
    B = 40,
    C = 60,
    D = 1000,
};

test "enum with specified tag values" {
    testEnumWithSpecifiedTagValues(MultipleChoice.C);
    comptime testEnumWithSpecifiedTagValues(MultipleChoice.C);
}

fn testEnumWithSpecifiedTagValues(x: MultipleChoice) void {
    assertOrPanic(@enumToInt(x) == 60);
    assertOrPanic(1234 == switch (x) {
        MultipleChoice.A => 1,
        MultipleChoice.B => 2,
        MultipleChoice.C => u32(1234),
        MultipleChoice.D => 4,
    });
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

test "enum with specified and unspecified tag values" {
    testEnumWithSpecifiedAndUnspecifiedTagValues(MultipleChoice2.D);
    comptime testEnumWithSpecifiedAndUnspecifiedTagValues(MultipleChoice2.D);
}

fn testEnumWithSpecifiedAndUnspecifiedTagValues(x: MultipleChoice2) void {
    assertOrPanic(@enumToInt(x) == 1000);
    assertOrPanic(1234 == switch (x) {
        MultipleChoice2.A => 1,
        MultipleChoice2.B => 2,
        MultipleChoice2.C => 3,
        MultipleChoice2.D => u32(1234),
        MultipleChoice2.Unspecified1 => 5,
        MultipleChoice2.Unspecified2 => 6,
        MultipleChoice2.Unspecified3 => 7,
        MultipleChoice2.Unspecified4 => 8,
        MultipleChoice2.Unspecified5 => 9,
    });
}

test "cast integer literal to enum" {
    assertOrPanic(@intToEnum(MultipleChoice2, 0) == MultipleChoice2.Unspecified1);
    assertOrPanic(@intToEnum(MultipleChoice2, 40) == MultipleChoice2.B);
}

const EnumWithOneMember = enum {
    Eof,
};

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

const State = enum {
    Start,
};
test "switch on enum with one member is comptime known" {
    var state = State.Start;
    switch (state) {
        State.Start => return,
    }
    @compileError("analysis should not reach here");
}

const EnumWithTagValues = enum(u4) {
    A = 1 << 0,
    B = 1 << 1,
    C = 1 << 2,
    D = 1 << 3,
};
test "enum with tag values don't require parens" {
    assertOrPanic(@enumToInt(EnumWithTagValues.C) == 0b0100);
}

test "enum with 1 field but explicit tag type should still have the tag type" {
    const Enum = enum(u8) {
        B = 2,
    };
    comptime @import("std").debug.assertOrPanic(@sizeOf(Enum) == @sizeOf(u8));
}

test "empty extern enum with members" {
    const E = extern enum {
        A,
        B,
        C,
    };
    assertOrPanic(@sizeOf(E) == @sizeOf(c_int));
}

test "aoeu" {
    const LocalFoo = enum {
        A = 1,
        B = 0,
    };
    var b = LocalFoo.B;
    assertOrPanic(mem.eql(u8, @tagName(b), "B"));
}
