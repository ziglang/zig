comptime {
    const undef: i64 = undefined;
    const not_undef: i64 = 32;

    // If the rhs is zero, then the other operand is returned, even if it is undefined.
    @compileLog(undef - 0);
    @compileLog(not_undef - 0);

    _ = undef - undef;
}

// error
// backend=stage2
// target=native
//
// :9:17: error: use of undefined value here causes undefined behavior
//
// Compile Log Output:
// @as(i64, undefined)
// @as(i64, 32)
