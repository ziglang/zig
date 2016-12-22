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


