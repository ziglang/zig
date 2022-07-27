export fn entry() void {
    var x: i32 = 1234;
    while (!@cmpxchgWeak(i32, &x, 1234, 5678, @as(u32, 1234), @as(u32, 1234))) {}
}

// error
// backend=stage2
// target=native
//
// :3:47: error: expected type 'builtin.AtomicOrder', found 'u32'
// :?:?: note: enum declared here
