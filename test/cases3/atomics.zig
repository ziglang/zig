fn cmpxchg() {
    @setFnTest(this);

    var x: i32 = 1234;
    while (!@cmpxchg(&x, 1234, 5678, AtomicOrder.SeqCst, AtomicOrder.SeqCst)) {}
    assert(x == 5678);
}

fn fence() {
    @setFnTest(this);

    var x: i32 = 1234;
    @fence(AtomicOrder.SeqCst);
    x = 5678;
}

// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}
