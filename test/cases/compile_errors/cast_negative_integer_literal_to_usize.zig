export fn entry() void {
    const x = @as(usize, -10);
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :2:26: error: type 'usize' cannot represent integer value '-10'
