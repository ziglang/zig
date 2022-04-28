export fn entry() void {
    const a: fn () anyopaque = undefined;
    _ = a;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:20: error: return type cannot be opaque
