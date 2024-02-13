comptime {
    const undef: i64 = undefined;
    const not_undef: i64 = 32;

    // If either of the operands are zero, then the other operand is returned.
    @compileLog(undef +% 0);
    @compileLog(not_undef +% 0);
    @compileLog(0 +% undef);
    @compileLog(0 +% not_undef);
    // If either of the operands are undefined, the result is undefined.
    @compileLog(undef +% 1);
    @compileLog(not_undef +% 1);
    @compileLog(1 +% undef);
    @compileLog(1 +% not_undef);
}

// error
// backend=stage2
// target=native
//
// :6:5: error: found compile log statement
//
// Compile Log Output:
// @as(i64, undefined)
// @as(i64, 32)
// @as(i64, undefined)
// @as(i64, 32)
// @as(i64, undefined)
// @as(i64, 33)
// @as(i64, undefined)
// @as(i64, 33)
