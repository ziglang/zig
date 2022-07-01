export fn entry(x: u8) u8 {
    return 0x11 << x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:17: error: LHS of shift must be a fixed-width integer type, or RHS must be compile-time known
