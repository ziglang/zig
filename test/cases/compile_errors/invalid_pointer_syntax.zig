export fn foo() void {
    var guid: *:0 const u8 = undefined;
}

// error
// backend=stage2
// target=native
//
// :2:16: error: expected type expression, found ':'
