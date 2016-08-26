const assert = @import("std").debug.assert;

enum Number {
    Zero,
    One,
    Two,
    Three,
    Four,
}

#attribute("test")
fn enumToInt() {
    shouldEqual(Number.Zero, 0);
    shouldEqual(Number.One, 1);
    shouldEqual(Number.Two, 2);
    shouldEqual(Number.Three, 3);
    shouldEqual(Number.Four, 4);
}

// TODO add test with this disabled
#static_eval_enable(false)
fn shouldEqual(n: Number, expected: usize) {
    assert(usize(n) == expected);
}
