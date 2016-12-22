fn whileLoop() {
    @setFnTest(this);

    var i : i32 = 0;
    while (i < 4) {
        i += 1;
    }
    assert(i == 4);
    assert(whileLoop1() == 1);
}
fn whileLoop1() -> i32 {
    return whileLoop2();
}
fn whileLoop2() -> i32 {
    while (true) {
        return 1;
    }
}
fn staticEvalWhile() {
    @setFnTest(this);

    assert(static_eval_while_number == 1);
}
const static_eval_while_number = staticWhileLoop1();
fn staticWhileLoop1() -> i32 {
    return whileLoop2();
}
fn staticWhileLoop2() -> i32 {
    while (true) {
        return 1;
    }
}

// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}
