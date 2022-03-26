export fn entry() void {
    @fence(.Monotonic);
}

// atomic orderings of fence Acquire or stricter
//
// tmp.zig:2:12: error: atomic ordering must be Acquire or stricter
