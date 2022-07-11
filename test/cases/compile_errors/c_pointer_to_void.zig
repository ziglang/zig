export fn entry() void {
    var a: [*c]void = undefined;
    _ = a;
}

// error
// backend=stage2
// target=native
//
// :1:1: error: C pointers cannot point to non-C-ABI-compatible type 'void'
// :1:1: note: 'void' is a zero bit type; for C 'void' use 'anyopaque'
