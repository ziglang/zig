// thisfileisautotranslatedfromc;

export fn a() void {
    const foo: [*c]u8 = undefined;
    _ = foo;
}

// error
// backend=stage2
// target=native
//
// :4:17: error: [*c] pointers are only allowed in auto-translated C code
// :4:17: note: * and [*] pointers may be used where a [*c] pointer is expected
