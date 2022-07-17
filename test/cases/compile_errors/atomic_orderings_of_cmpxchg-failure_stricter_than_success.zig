const AtomicOrder = @import("std").builtin.AtomicOrder;
export fn f() void {
    var x: i32 = 1234;
    while (!@cmpxchgWeak(i32, &x, 1234, 5678, AtomicOrder.Monotonic, AtomicOrder.SeqCst)) {}
}

// error
// backend=stage2
// target=native
//
// :4:81: error: failure atomic ordering must be no stricter than success
