export fn entry() void {
    const foo = "	hello";
    _ = foo;
}

// error
// backend=stage2
// target=native
//
// :2:18: error: string literal contains invalid byte: '\t'
