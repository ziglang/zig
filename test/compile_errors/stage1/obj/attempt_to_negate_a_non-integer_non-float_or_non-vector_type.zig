fn foo() anyerror!u32 {
    return 1;
}

export fn entry() void {
    const x = -foo();
    _ = x;
}

// attempt to negate a non-integer, non-float or non-vector type
//
// tmp.zig:6:15: error: negation of type 'anyerror!u32'
