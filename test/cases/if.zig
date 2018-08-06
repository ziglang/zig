const assert = @import("std").debug.assert;

test "if statements" {
    shouldBeEqual(1, 1);
    firstEqlThird(2, 1, 2);
}
fn shouldBeEqual(a: i32, b: i32) void {
    if (a != b) {
        unreachable;
    } else {
        return;
    }
}
fn firstEqlThird(a: i32, b: i32, c: i32) void {
    if (a == b) {
        unreachable;
    } else if (b == c) {
        unreachable;
    } else if (a == c) {
        return;
    } else {
        unreachable;
    }
}

test "else if expression" {
    assert(elseIfExpressionF(1) == 1);
}
fn elseIfExpressionF(c: u8) u8 {
    if (c == 0) {
        return 0;
    } else if (c == 1) {
        return 1;
    } else {
        return u8(2);
    }
}
