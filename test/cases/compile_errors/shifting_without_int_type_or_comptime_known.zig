export fn entry(x: u8) u8 {
    return 0x11 << x;
}
export fn entry1(x: u8) u8 {
    return 0x11 >> x;
}
export fn entry2() void {
    var x: u5 = 1;
    _ = @shlExact(12345, x);
}
export fn entry3() void {
    var x: u5 = 1;
    _ = @shrExact(12345, x);
}

// error
// backend=stage2
// target=native
//
// :2:17: error: LHS of shift must be a fixed-width integer type, or RHS must be comptime-known
// :5:17: error: LHS of shift must be a fixed-width integer type, or RHS must be comptime-known
// :9:9: error: LHS of shift must be a fixed-width integer type, or RHS must be comptime-known
// :13:9: error: LHS of shift must be a fixed-width integer type, or RHS must be comptime-known
