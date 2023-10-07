export fn foo() void {
    var ptr: [*]u8 = undefined;
    @memset(ptr, 123);
}
export fn bar() void {
    var ptr: [*c]bool = undefined;
    @memset(ptr, true);
}

// error
// backend=stage2
// target=native
//
// :3:5: error: unknown @memset length
// :3:13: note: destination type '[*]u8' provides no length
// :7:5: error: unknown @memset length
// :7:13: note: destination type '[*c]bool' provides no length
