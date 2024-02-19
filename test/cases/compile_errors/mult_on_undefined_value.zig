comptime {
    const undef: i64 = undefined;
    const not_undef: i64 = 32;

    // If either of the operands are zero, the result is zero.
    @compileLog(undef * 0);
    @compileLog(not_undef * 0);
    @compileLog(0 * undef);
    @compileLog(0 * not_undef);

    // If either of the operands are one, the result is the other
    // operand, even if it is undefined.
    @compileLog(undef * 1);
    @compileLog(not_undef * 1);
    @compileLog(1 * undef);
    @compileLog(1 * not_undef);

    // If either of the operands are undefined, it's a compile error
    // because there is a possible value for which the addition would
    // overflow (max_int), causing illegal behavior.
    _ = undef * undef;
}

// error
// backend=stage2
// target=native
//
// :21:17: error: use of undefined value here causes undefined behavior
//
// Compile Log Output:
// @as(i64, 0)
// @as(i64, 0)
// @as(i64, 0)
// @as(i64, 0)
// @as(i64, undefined)
// @as(i64, 32)
// @as(i64, undefined)
// @as(i64, 32)
