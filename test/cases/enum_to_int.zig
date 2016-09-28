const assert = @import("std").debug.assert;

enum Number {
    Zero,
    One,
    Two,
    Three,
    Four,
}

fn enumToInt() {
    @setFnTest(this, true);

    shouldEqual(false, Number.Zero, 0);
    shouldEqual(false, Number.One, 1);
    shouldEqual(false, Number.Two, 2);
    shouldEqual(false, Number.Three, 3);
    shouldEqual(false, Number.Four, 4);

    shouldEqual(true, Number.Zero, 0);
    shouldEqual(true, Number.One, 1);
    shouldEqual(true, Number.Two, 2);
    shouldEqual(true, Number.Three, 3);
    shouldEqual(true, Number.Four, 4);
}

fn shouldEqual(inline static_eval: bool, n: Number, expected: usize) {
    @setFnStaticEval(this, static_eval);

    assert(usize(n) == expected);
}
