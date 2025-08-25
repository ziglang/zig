export fn entry() void {
    const a: fn () anyopaque = undefined;
    _ = a;
}

// error
// backend=stage2
// target=native
//
// :2:20: error: opaque return type 'anyopaque' not allowed
