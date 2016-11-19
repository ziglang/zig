// These functions are provided when not linking against libc because LLVM
// sometimes generates code that calls them.

// TODO dest should be nullable and return value should be nullable
export fn memset(dest: &u8, c: u8, n: usize) -> &u8 {
    @setDebugSafety(this, false);

    var index: usize = 0;
    while (index != n; index += 1)
        dest[index] = c;

    return dest;
}

// TODO dest, source, and return value should be nullable
export fn memcpy(noalias dest: &u8, noalias src: &const u8, n: usize) -> &u8 {
    @setDebugSafety(this, false);

    var index: usize = 0;
    while (index != n; index += 1)
        dest[index] = src[index];

    return dest;
}
