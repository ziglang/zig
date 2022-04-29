export fn foo() void {
    var b: u8[40] = undefined;
    _ = b;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:14: error: array access of non-array type 'type'
