const assertOrPanic = @import("std").debug.assertOrPanic;

test "switch with numbers" {
    testSwitchWithNumbers(13);
}

fn testSwitchWithNumbers(x: u32) void {
    const result = switch (x) {
        1, 2, 3, 4...8 => false,
        13 => true,
        else => false,
    };
    assertOrPanic(result);
}

test "switch with all ranges" {
    assertOrPanic(testSwitchWithAllRanges(50, 3) == 1);
    assertOrPanic(testSwitchWithAllRanges(101, 0) == 2);
    assertOrPanic(testSwitchWithAllRanges(300, 5) == 3);
    assertOrPanic(testSwitchWithAllRanges(301, 6) == 6);
}

fn testSwitchWithAllRanges(x: u32, y: u32) u32 {
    return switch (x) {
        0...100 => 1,
        101...200 => 2,
        201...300 => 3,
        else => y,
    };
}

test "implicit comptime switch" {
    const x = 3 + 4;
    const result = switch (x) {
        3 => 10,
        4 => 11,
        5, 6 => 12,
        7, 8 => 13,
        else => 14,
    };

    comptime {
        assertOrPanic(result + 1 == 14);
    }
}

test "switch on enum" {
    const fruit = Fruit.Orange;
    nonConstSwitchOnEnum(fruit);
}
const Fruit = enum {
    Apple,
    Orange,
    Banana,
};
fn nonConstSwitchOnEnum(fruit: Fruit) void {
    switch (fruit) {
        Fruit.Apple => unreachable,
        Fruit.Orange => {},
        Fruit.Banana => unreachable,
    }
}

test "switch statement" {
    nonConstSwitch(SwitchStatmentFoo.C);
}
fn nonConstSwitch(foo: SwitchStatmentFoo) void {
    const val = switch (foo) {
        SwitchStatmentFoo.A => i32(1),
        SwitchStatmentFoo.B => 2,
        SwitchStatmentFoo.C => 3,
        SwitchStatmentFoo.D => 4,
    };
    assertOrPanic(val == 3);
}
const SwitchStatmentFoo = enum {
    A,
    B,
    C,
    D,
};

test "switch prong with variable" {
    switchProngWithVarFn(SwitchProngWithVarEnum{ .One = 13 });
    switchProngWithVarFn(SwitchProngWithVarEnum{ .Two = 13.0 });
    switchProngWithVarFn(SwitchProngWithVarEnum{ .Meh = {} });
}
const SwitchProngWithVarEnum = union(enum) {
    One: i32,
    Two: f32,
    Meh: void,
};
fn switchProngWithVarFn(a: SwitchProngWithVarEnum) void {
    switch (a) {
        SwitchProngWithVarEnum.One => |x| {
            assertOrPanic(x == 13);
        },
        SwitchProngWithVarEnum.Two => |x| {
            assertOrPanic(x == 13.0);
        },
        SwitchProngWithVarEnum.Meh => |x| {
            const v: void = x;
        },
    }
}

