export fn a() void {
    const foo: [*c]u8 = undefined;
    _ = foo;
}

thisfileisautotranslatedfromc;

// error
// backend=stage2
// target=native
//
// :6:1: error: thisfileisautotranslatedfromc must be the first token in the file
