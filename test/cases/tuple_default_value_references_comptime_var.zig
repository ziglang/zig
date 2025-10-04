export fn foo() void {
    comptime var a: u8 = 0;
    const S = struct { comptime *u8 = &a };
    _ = S;
}

// error
//
// :1:8: error: field default value contains reference to comptime var
// :2:14: note: '0' points to comptime var declared here
