// These functions are provided when not linking against libc because LLVM
// sometimes generates code that calls them.

export fn memset(dest: ?&u8, c: u8, n: usize) -> ?&u8 {
    @setDebugSafety(this, false);

    if (n == 0)
        return dest;

    const d = ??dest;
    var index: usize = 0;
    while (index != n; index += 1)
        d[index] = c;

    return dest;
}

export fn memcpy(noalias dest: ?&u8, noalias src: ?&const u8, n: usize) -> ?&u8 {
    @setDebugSafety(this, false);

    if (n == 0)
        return dest;

    const d = ??dest;
    const s = ??src;
    var index: usize = 0;
    while (index != n; index += 1)
        d[index] = s[index];

    return dest;
}
