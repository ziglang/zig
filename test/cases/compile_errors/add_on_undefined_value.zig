comptime {
    const undef: i64 = undefined;
    const not_undef: i64 = 32;

    // If either of the operands are zero, then the other operand is returned.
    @compileLog(undef + 0);
    @compileLog(not_undef + 0);
    @compileLog(0 + undef);
    @compileLog(0 + not_undef);

    _ = undef + undef;
}

// error
// backend=stage2
// target=native
//
// :11:17: error: use of undefined value here causes undefined behavior
//
// Compile Log Output:
// @as(i64, undefined)
// @as(i64, 32)
// @as(i64, undefined)
// @as(i64, 32)
