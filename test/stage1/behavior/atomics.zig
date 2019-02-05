const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;
const builtin = @import("builtin");
const AtomicRmwOp = builtin.AtomicRmwOp;
const AtomicOrder = builtin.AtomicOrder;

test "cmpxchg" {
    var x: i32 = 1234;
    if (@cmpxchgWeak(i32, &x, 99, 5678, AtomicOrder.SeqCst, AtomicOrder.SeqCst)) |x1| {
        assertOrPanic(x1 == 1234);
    } else {
        @panic("cmpxchg should have failed");
    }

    while (@cmpxchgWeak(i32, &x, 1234, 5678, AtomicOrder.SeqCst, AtomicOrder.SeqCst)) |x1| {
        assertOrPanic(x1 == 1234);
    }
    assertOrPanic(x == 5678);

    assertOrPanic(@cmpxchgStrong(i32, &x, 5678, 42, AtomicOrder.SeqCst, AtomicOrder.SeqCst) == null);
    assertOrPanic(x == 42);
}

test "fence" {
    var x: i32 = 1234;
    @fence(AtomicOrder.SeqCst);
    x = 5678;
}

test "atomicrmw and atomicload" {
    var data: u8 = 200;
    testAtomicRmw(&data);
    assertOrPanic(data == 42);
    testAtomicLoad(&data);
}

fn testAtomicRmw(ptr: *u8) void {
    const prev_value = @atomicRmw(u8, ptr, AtomicRmwOp.Xchg, 42, AtomicOrder.SeqCst);
    assertOrPanic(prev_value == 200);
    comptime {
        var x: i32 = 1234;
        const y: i32 = 12345;
        assertOrPanic(@atomicLoad(i32, &x, AtomicOrder.SeqCst) == 1234);
        assertOrPanic(@atomicLoad(i32, &y, AtomicOrder.SeqCst) == 12345);
    }
}

fn testAtomicLoad(ptr: *u8) void {
    const x = @atomicLoad(u8, ptr, AtomicOrder.SeqCst);
    assertOrPanic(x == 42);
}

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
