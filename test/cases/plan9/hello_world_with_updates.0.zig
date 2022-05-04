pub fn main() void {
    const str = "Hello World!\n";
    asm volatile (
        \\push $0
        \\push %%r10
        \\push %%r11
        \\push $1
        \\push $0
        \\syscall
        \\pop %%r11
        \\pop %%r11
        \\pop %%r11
        \\pop %%r11
        \\pop %%r11
        :
        // pwrite
        : [syscall_number] "{rbp}" (51),
          [hey] "{r11}" (@ptrToInt(str)),
          [strlen] "{r10}" (str.len),
        : "rcx", "rbp", "r11", "memory"
    );
}

// run
// target=x86_64-plan9
//
// Hello World
//
