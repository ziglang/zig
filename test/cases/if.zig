const assert = @import("std").debug.assert;

fn ifStatements() {
    @setFnTest(this);

    shouldBeEqual(1, 1);
    firstEqlThird(2, 1, 2);
}
fn shouldBeEqual(a: i32, b: i32) {
    if (a != b) {
        @unreachable();
    } else {
        return;
    }
}
fn firstEqlThird(a: i32, b: i32, c: i32) {
    if (a == b) {
        @unreachable();
    } else if (b == c) {
        @unreachable();
    } else if (a == c) {
        return;
    } else {
        @unreachable();
    }
}


fn elseIfExpression() {
    @setFnTest(this);

    assert(elseIfExpressionF(1) == 1);
}
fn elseIfExpressionF(c: u8) -> u8 {
    if (c == 0) {
        0
    } else if (c == 1) {
        1
    } else {
        u8(2)
    }
}
