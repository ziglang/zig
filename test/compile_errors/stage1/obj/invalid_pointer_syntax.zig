export fn foo() void {
    var guid: *:0 const u8 = undefined;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:16: error: expected type expression, found ':'
