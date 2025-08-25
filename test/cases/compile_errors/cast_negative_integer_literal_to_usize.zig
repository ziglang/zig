export fn entry() void {
    const x = @as(usize, -10);
    _ = x;
}
export fn entry1() void {
    const x = @as(usize, -10.0);
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :2:26: error: type 'usize' cannot represent integer value '-10'
// :6:26: error: float value '-10' cannot be stored in integer type 'usize'
