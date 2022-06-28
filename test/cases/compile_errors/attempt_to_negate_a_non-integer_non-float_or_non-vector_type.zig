fn foo() anyerror!u32 {
    return 1;
}

export fn entry() void {
    const x = -foo();
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :6:15: error: negation of type 'anyerror!u32'
