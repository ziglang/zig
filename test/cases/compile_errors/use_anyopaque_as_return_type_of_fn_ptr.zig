export fn entry() void {
    const a: fn () anyopaque = undefined;
    _ = a;
}

// error
//
// :2:20: error: opaque return type 'anyopaque' not allowed
