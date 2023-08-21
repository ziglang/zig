export fn foo() void {
    const x = 1;
    const ptr: *comptime_int = @constCast(&x);
    ptr.* = 123;
}
export fn bar() void {
    const T = u32;
    const ptr: *type = @constCast(&T);
    ptr.* = anyopaque;
}

// error
// backend=stage2
// target=native
//
// :4:11: error: cannot assign to constant
// :4:8: note: mutable pointer refers to constant data
// :9:11: error: cannot assign to constant
// :9:8: note: mutable pointer refers to constant data
