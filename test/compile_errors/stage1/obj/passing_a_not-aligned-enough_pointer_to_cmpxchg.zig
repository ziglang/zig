const AtomicOrder = @import("std").builtin.AtomicOrder;
export fn entry() bool {
    var x: i32 align(1) = 1234;
    while (!@cmpxchgWeak(i32, &x, 1234, 5678, AtomicOrder.SeqCst, AtomicOrder.SeqCst)) {}
    return x == 5678;
}

// passing a not-aligned-enough pointer to cmpxchg
//
// tmp.zig:4:32: error: expected type '*i32', found '*align(1) i32'
