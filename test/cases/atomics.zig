const assert = @import("std").debug.assert;

test "cmpxchg" {
    var x: i32 = 1234;
    while (!@cmpxchg(&x, 1234, 5678, AtomicOrder.SeqCst, AtomicOrder.SeqCst)) {}
    assert(x == 5678);
}

test "fence" {
    var x: i32 = 1234;
    @fence(AtomicOrder.SeqCst);
    x = 5678;
}
