export fn entry() void {
    @fence(.Monotonic);
}

// error
// backend=stage2
// target=native
//
// :2:13: error: atomic ordering must be Acquire or stricter
