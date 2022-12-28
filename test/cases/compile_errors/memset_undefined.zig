export fn foo() void {
    var x: u32 = 10;
    const ptr: *volatile u32 = &x;
    @memset(@ptrCast([*]volatile u8, ptr), undefined, 4);
}

export fn bar() void {
    var x: u32 = 10;
    const y: u32 = undefined;
    const ptr: *volatile u32 = &x;
    @memset(@ptrCast([*]volatile u8, ptr), y, 4);
}

// error
//
// :4:5: error: storing an undefined value to a volatile pointer is not allowed
// :11:5: error: storing an undefined value to a volatile pointer is not allowed
