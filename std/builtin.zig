// These functions are provided when not linking against libc because LLVM
// sometimes generates code that calls them.

#debug_safety(false)
export fn memset(dest: &u8, c: u8, n: isize) -> &u8 {
    var index: isize = 0;
    while (index != n) {
        dest[index] = c;
        index += 1;
    }
    return dest;
}

#debug_safety(false)
export fn memcpy(noalias dest: &u8, noalias src: &const u8, n: isize) -> &u8 {
    var index: isize = 0;
    while (index != n) {
        dest[index] = src[index];
        index += 1;
    }
    return dest;
}
