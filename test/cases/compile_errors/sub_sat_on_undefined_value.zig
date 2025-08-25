comptime {
    const undef: i64 = undefined;
    const not_undef: i64 = 32;

    // If the RHS is zero, then the LHS is returned, even if it is undefined.
    @compileLog(undef -| 0);
    @compileLog(not_undef -| 0);
    // If either of the operands are undefined, the result is undefined.
    @compileLog(undef -| not_undef);
    @compileLog(not_undef -| undef);
    @compileLog(undef -| undef);
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
// @as(i64, undefined)
// @as(i64, undefined)
