const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;
const builtin = @import("builtin");
const AtomicRmwOp = builtin.AtomicRmwOp;
const AtomicOrder = builtin.AtomicOrder;

test "cmpxchg with ptr" {
    var data1: i32 = 1234;
    var data2: i32 = 5678;
    var data3: i32 = 9101;
    var x: *i32 = &data1;
    if (@cmpxchgWeak(*i32, &x, &data2, &data3, AtomicOrder.SeqCst, AtomicOrder.SeqCst)) |x1| {
        assertOrPanic(x1 == &data1);
    } else {
        @panic("cmpxchg should have failed");
    }

    while (@cmpxchgWeak(*i32, &x, &data1, &data3, AtomicOrder.SeqCst, AtomicOrder.SeqCst)) |x1| {
        assertOrPanic(x1 == &data1);
    }
    assertOrPanic(x == &data3);

    assertOrPanic(@cmpxchgStrong(*i32, &x, &data3, &data2, AtomicOrder.SeqCst, AtomicOrder.SeqCst) == null);
    assertOrPanic(x == &data2);
}
