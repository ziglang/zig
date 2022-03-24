export fn foo() void {
    var b: u8[40] = undefined;
    _ = b;
}

// array access of type
//
// tmp.zig:2:14: error: array access of non-array type 'type'
