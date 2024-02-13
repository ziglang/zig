pub export fn entry() void {
    const E = enum(comptime_int) { a, b, c, _ };
    var e: E = .a;
    _ = &e;
}

// error
// backend=stage2
// target=native
//
// :3:12: error: variable of type 'tmp.entry.E' must be const or comptime
