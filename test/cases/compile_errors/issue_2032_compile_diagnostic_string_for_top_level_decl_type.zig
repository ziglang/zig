export fn entry() void {
    const foo: u32 = @This(){};
    _ = foo;
}

// error
// backend=stage2
// target=native
//
// :2:29: error: expected type 'u32', found 'tmp'
// :1:1: note: struct declared here
