export fn foo(ptr: *u8) void {
    const slice: []align(1) u16 = @ptrCast(ptr);
    _ = slice;
}

// error
//
// :2:35: error: type 'u8' does not divide exactly into destination elements
