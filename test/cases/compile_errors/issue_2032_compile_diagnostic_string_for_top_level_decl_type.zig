export fn entry() void {
    var foo: u32 = @This(){};
    _ = foo;
}

// error
// backend=stage2
// target=native
//
// :2:27: error: expected type 'u32', found 'tmp'
// :1:1: note: struct declared here
