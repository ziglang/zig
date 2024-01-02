thisfileisautotranslatedfromc;

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
// :6:5: error: unknown @memset length
// :6:13: note: destination type '[*]u8' provides no length
// :11:5: error: unknown @memset length
// :11:13: note: destination type '[*c]bool' provides no length
