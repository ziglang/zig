const AtomicOrder = @import("std").builtin.AtomicOrder;
export fn f() void {
    var x: i32 = 1234;
    while (!@cmpxchgWeak(i32, &x, 1234, 5678, AtomicOrder.unordered, AtomicOrder.unordered)) {}
}

// error
// backend=stage2
// target=native
//
// :4:58: error: success atomic ordering must be monotonic or stricter
