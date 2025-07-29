export fn a() void {
    errdefer |_| {
        @"_";
    }
}
export fn b() void {
    const x: error{}!void = {};
    x catch |_| {
        @"_";
    };
}
export fn c() void {
    const x: error{}!void = {};
    x catch |_| switch (_) {};
}
export fn d() void {
    const x: error{}!u32 = 0;
    if (x) |v| v else |_| switch (_) {}
}

// error
// backend=stage2
// target=native
//
// :2:15: error: discard of error capture; omit it instead
// :3:9: error: use of undeclared identifier '_'
// :8:14: error: discard of error capture; omit it instead
// :9:9: error: use of undeclared identifier '_'
// :14:14: error: discard of error capture; omit it instead
// :18:24: error: discard of error capture; omit it instead
