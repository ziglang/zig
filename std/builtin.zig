// These functions are provided when not linking against libc because LLVM
// sometimes generates code that calls them.

export fn memset(dest: &u8, c: u8, n: usize) -> &u8 {
    var index : #typeof(n) = 0;
    while (index != n) {
        dest[index] = c;
        index += 1;
    }
    return dest;
}

export fn memcpy(dest: &u8, src: &const u8, n: usize) -> &u8 {
    var index : #typeof(n) = 0;
    while (index != n) {
        dest[index] = src[index];
        index += 1;
    }
    return dest;
}
