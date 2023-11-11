export fn foo() void {
    var ptr: [*]u8 = undefined;
    _ = &ptr;
    @memset(ptr, 123);
}
export fn bar() void {
    var ptr: [*c]bool = undefined;
    _ = &ptr;
    @memset(ptr, true);
}

// error
// backend=stage2
// target=native
//
// :4:5: error: unknown @memset length
// :4:13: note: destination type '[*]u8' provides no length
// :9:5: error: unknown @memset length
// :9:13: note: destination type '[*c]bool' provides no length
