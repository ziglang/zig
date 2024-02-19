const AtomicOrder = @import("std").builtin.AtomicOrder;
export fn entry() bool {
    var x: i32 align(1) = 1234;
    while (!@cmpxchgWeak(i32, &x, 1234, 5678, AtomicOrder.seq_cst, AtomicOrder.seq_cst)) {}
    return x == 5678;
}

// error
// backend=stage2
// target=native
//
// :4:31: error: expected type '*i32', found '*align(1) i32'
// :4:31: note: pointer alignment '1' cannot cast into pointer alignment '4'
