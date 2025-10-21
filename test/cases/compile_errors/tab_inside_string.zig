export fn entry() void {
    const foo = "	hello";
    _ = foo;
}

// error
//
// :2:18: error: string literal contains invalid byte: '\t'
