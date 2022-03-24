const AtomicOrder = @import("std").builtin.AtomicOrder;
export fn f() void {
    var x: i32 = 1234;
    while (!@cmpxchgWeak(i32, &x, 1234, 5678, AtomicOrder.Unordered, AtomicOrder.Unordered)) {}
}

// atomic orderings of cmpxchg - success Monotonic or stricter
//
// tmp.zig:4:58: error: success atomic ordering must be Monotonic or stricter
