export fn entry() void {
    var foo: u32 = @This(){};
    _ = foo;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:27: error: type 'u32' does not support array initialization
