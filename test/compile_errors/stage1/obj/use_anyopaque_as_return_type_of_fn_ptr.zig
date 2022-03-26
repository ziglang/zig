export fn entry() void {
    const a: fn () anyopaque = undefined;
    _ = a;
}

// use anyopaque as return type of fn ptr
//
// tmp.zig:2:20: error: return type cannot be opaque
