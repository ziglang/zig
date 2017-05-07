const assert = @import("std").debug.assert;

test "switch with numbers" {
    testSwitchWithNumbers(13);
}

fn testSwitchWithNumbers(x: u32) {
    const result = switch (x) {
        1, 2, 3, 4 ... 8 => false,
        13 => true,
        else => false,
    };
    assert(result);
}

test "switch with all ranges" {
    assert(testSwitchWithAllRanges(50, 3) == 1);
    assert(testSwitchWithAllRanges(101, 0) == 2);
    assert(testSwitchWithAllRanges(300, 5) == 3);
    assert(testSwitchWithAllRanges(301, 6) == 6);
}

fn testSwitchWithAllRanges(x: u32, y: u32) -> u32 {
    switch (x) {
        0 ... 100 => 1,
        101 ... 200 => 2,
        201 ... 300 => 3,
        else => y,
    }
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
        assert(result + 1 == 14);
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
fn nonConstSwitchOnEnum(fruit: Fruit) {
    switch (fruit) {
        Fruit.Apple => unreachable,
        Fruit.Orange => {},
        Fruit.Banana => unreachable,
    }
}


test "switch statement" {
    nonConstSwitch(SwitchStatmentFoo.C);
}
fn nonConstSwitch(foo: SwitchStatmentFoo) {
    const val = switch (foo) {
        SwitchStatmentFoo.A => i32(1),
        SwitchStatmentFoo.B => 2,
        SwitchStatmentFoo.C => 3,
        SwitchStatmentFoo.D => 4,
    };
    if (val != 3) unreachable;
}
const SwitchStatmentFoo = enum {
    A,
    B,
    C,
    D,
};


test "switch prong with variable" {
    switchProngWithVarFn(SwitchProngWithVarEnum.One {13});
    switchProngWithVarFn(SwitchProngWithVarEnum.Two {13.0});
    switchProngWithVarFn(SwitchProngWithVarEnum.Meh);
}
const SwitchProngWithVarEnum = enum {
    One: i32,
    Two: f32,
    Meh,
};
fn switchProngWithVarFn(a: &const SwitchProngWithVarEnum) {
    switch(*a) {
        SwitchProngWithVarEnum.One => |x| {
            if (x != 13) unreachable;
        },
        SwitchProngWithVarEnum.Two => |x| {
            if (x != 13.0) unreachable;
        },
        SwitchProngWithVarEnum.Meh => |x| {
            const v: void = x;
        },
    }
}


test "switch with multiple expressions" {
    const x = switch (returnsFive()) {
        1, 2, 3 => 1,
        4, 5, 6 => 2,
        else => i32(3),
    };
    assert(x == 2);
}
fn returnsFive() -> i32 {
    5
}


const Number = enum {
    One: u64,
    Two: u8,
    Three: f32,
};

const number = Number.Three { 1.23 };

fn returnsFalse() -> bool {
    switch (number) {
        Number.One => |x| return x > 1234,
        Number.Two => |x| return x == 'a',
        Number.Three => |x| return x > 12.34,
    }
}
test "switch on const enum with var" {
    assert(!returnsFalse());
}

test "switch on type" {
    assert(trueIfBoolFalseOtherwise(bool));
    assert(!trueIfBoolFalseOtherwise(i32));
}

fn trueIfBoolFalseOtherwise(comptime T: type) -> bool {
    switch (T) {
        bool => true,
        else => false,
    }
}

test "switch handles all cases of number" {
    testSwitchHandleAllCases();
    comptime testSwitchHandleAllCases();
}

const u2 = @IntType(false, 2);
fn testSwitchHandleAllCases() {
    assert(testSwitchHandleAllCasesExhaustive(0) == 3);
    assert(testSwitchHandleAllCasesExhaustive(1) == 2);
    assert(testSwitchHandleAllCasesExhaustive(2) == 1);
    assert(testSwitchHandleAllCasesExhaustive(3) == 0);

    assert(testSwitchHandleAllCasesRange(100) == 0);
    assert(testSwitchHandleAllCasesRange(200) == 1);
    assert(testSwitchHandleAllCasesRange(201) == 2);
    assert(testSwitchHandleAllCasesRange(202) == 4);
    assert(testSwitchHandleAllCasesRange(230) == 3);
}

fn testSwitchHandleAllCasesExhaustive(x: u2) -> u2 {
    switch (x) {
        0 => u2(3),
        1 => 2,
        2 => 1,
        3 => 0,
    }
}

fn testSwitchHandleAllCasesRange(x: u8) -> u8 {
    switch (x) {
        0 ... 100 => u8(0),
        101 ... 200 => 1,
        201, 203 => 2,
        202 => 4,
        204 ... 255 => 3,
    }
}
