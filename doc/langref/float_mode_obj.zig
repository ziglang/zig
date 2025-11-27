const std = @import("std");
const big = @as(f64, 1 << 40);

export fn fooStrict(x: f64) f64 {
    return x + big - big;
}

export fn fooOptimized(x: f64) f64 {
    @setFloatMode(.optimized);
    return x + big - big;
}

// obj
// optimize=ReleaseFast
// disable_cache
