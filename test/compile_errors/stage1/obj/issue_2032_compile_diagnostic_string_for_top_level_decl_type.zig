export fn entry() void {
    var foo: u32 = @This(){};
    _ = foo;
}

// compile diagnostic string for top level decl type (issue 2032)
//
// tmp.zig:2:27: error: type 'u32' does not support array initialization
