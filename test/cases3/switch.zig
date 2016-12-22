fn switchWithNumbers() {
    @setFnTest(this);

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

fn switchWithAllRanges() {
    @setFnTest(this);

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

fn inlineSwitch() {
    @setFnTest(this);

    const x = 3 + 4;
    const result = inline switch (x) {
        3 => 10,
        4 => 11,
        5, 6 => 12,
        7, 8 => 13,
        else => 14,
    };
    assert(result + 1 == 14);
}

fn switchOnEnum() {
    @setFnTest(this);

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
        Fruit.Apple => @unreachable(),
        Fruit.Orange => {},
        Fruit.Banana => @unreachable(),
    }
}


fn switchStatement() {
    @setFnTest(this);

    nonConstSwitch(SwitchStatmentFoo.C);
}
fn nonConstSwitch(foo: SwitchStatmentFoo) {
    const val = switch (foo) {
        SwitchStatmentFoo.A => i32(1),
        SwitchStatmentFoo.B => 2,
        SwitchStatmentFoo.C => 3,
        SwitchStatmentFoo.D => 4,
    };
    if (val != 3) @unreachable();
}
const SwitchStatmentFoo = enum {
    A,
    B,
    C,
    D,
};




// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}
