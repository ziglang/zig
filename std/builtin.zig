// These functions are provided when not linking against libc because LLVM
// sometimes generates code that calls them.

// In the future we may put these functions in separate compile units, make them .o files,
// and then use
// ar rcs foo.a foo.o memcpy.o memset.o
// ld -o foo foo.a
// This will omit the machine code if the function is unused.

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
