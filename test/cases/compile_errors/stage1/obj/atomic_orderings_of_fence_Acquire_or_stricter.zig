export fn entry() void {
    @fence(.Monotonic);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:12: error: atomic ordering must be Acquire or stricter
