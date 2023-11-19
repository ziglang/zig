export fn entry() void {
    const a: [*c]void = undefined;
    _ = a;
}

// error
// backend=stage2
// target=native
//
// :2:18: error: C pointers cannot point to non-C-ABI-compatible type 'void'
// :2:18: note: 'void' is a zero bit type; for C 'void' use 'anyopaque'
