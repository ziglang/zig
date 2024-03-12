export fn entry() void {
    @fence(.monotonic);
}

// error
// backend=stage2
// target=native
//
// :2:13: error: atomic ordering must be acquire or stricter
