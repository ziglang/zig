
// TODO conditionally compile this differently for non-ELF
#attribute("naked")
export fn _start() -> unreachable {
    // TODO conditionally compile this differently for other architectures and other OSes
    asm volatile ("
        mov (%%rsp), %%rdi              // first parameter is argc
        lea 0x8(%%rsp), %%rsi           // second parameter is argv
        lea 0x10(%%rsp,%%rdi,8), %%rdx  // third paremeter is env
        callq main
        mov %%rax, %%rdi                // return value is the parameter to exit syscall
        mov $60, %%rax                  // 60 is exit syscall number
        syscall
    ");
    unreachable
}
