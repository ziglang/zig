// These functions are provided when not linking against libc because LLVM
// sometimes generates code that calls them.

export fn memset(dest: &u8, c: u8, n: usize) -> &u8 {
    @setDebugSafety(this, false);

    var index: usize = 0;
    while (index != n) {
        dest[index] = c;
        index += 1;
    }
    return dest;
}

export fn memcpy(noalias dest: &u8, noalias src: &const u8, n: usize) -> &u8 {
    @setDebugSafety(this, false);

    var index: usize = 0;
    while (index != n) {
        dest[index] = src[index];
        index += 1;
    }
    return dest;
}
