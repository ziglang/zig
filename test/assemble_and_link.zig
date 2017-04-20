const tests = @import("tests.zig");

pub fn addCases(cases: &tests.CompareOutputContext) {
    if (@compileVar("os") == Os.linux and @compileVar("arch") == Arch.x86_64) {
        cases.addAsm("hello world linux x86_64",
            \\.text
            \\.globl _start
            \\
            \\_start:
            \\    mov rax, 1
            \\    mov rdi, 1
            \\    lea rsi, msg
            \\    mov rdx, 14
            \\    syscall
            \\
            \\    mov rax, 60
            \\    mov rdi, 0
            \\    syscall
            \\
            \\.data
            \\
            \\msg:
            \\    .ascii "Hello, world!\n"
        , "Hello, world!\n");
    }
}
