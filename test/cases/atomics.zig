const assert = @import("std").debug.assert;
const builtin = @import("builtin");
const AtomicRmwOp = builtin.AtomicRmwOp;
const AtomicOrder = builtin.AtomicOrder;

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

test "atomicrmw and atomicload" {
    var data: u8 = 200;
    testAtomicRmw(&data);
    assert(data == 42);
    testAtomicLoad(&data);
}

fn testAtomicRmw(ptr: &u8) void {
    const prev_value = @atomicRmw(u8, ptr, AtomicRmwOp.Xchg, 42, AtomicOrder.SeqCst);
    assert(prev_value == 200);
    comptime {
        var x: i32 = 1234;
        const y: i32 = 12345;
        assert(@atomicLoad(i32, &x, AtomicOrder.SeqCst) == 1234);
        assert(@atomicLoad(i32, &y, AtomicOrder.SeqCst) == 12345);
    }
}

fn testAtomicLoad(ptr: &u8) void {
    const x = @atomicLoad(u8, ptr, AtomicOrder.SeqCst);
    assert(x == 42);
}
