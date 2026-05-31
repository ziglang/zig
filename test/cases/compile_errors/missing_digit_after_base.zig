export fn entry() void {
    const x = @as(usize, -0x);
    _ = x;
}

// error
//
// :2:27: error: expected a digit after base prefix
