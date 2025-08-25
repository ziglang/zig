pub export fn entry() void {
    comptime unreachable;
}

// error
// target=native
// backend=stage2
//
// :2:14: error: reached unreachable code
