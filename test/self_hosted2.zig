fn add(a: i32, b: i32) -> i32 {
    a + b
}

fn assert(ok: bool) {
    if (!ok) @unreachable();
}

fn testAdd() {
    @setFnTest(this, true);

    assert(add(2, 3) == 5);
}
