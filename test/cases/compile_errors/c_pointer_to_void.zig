export fn entry() void {
    var a: [*c]void = undefined;
    _ = a;
}

// error
// backend=stage2
// target=native
//
// :2:16: error: C pointers cannot point to non-C-ABI-compatible type 'void'
// :2:16: note: 'void' is a zero bit type; for C 'void' use 'anyopaque'
