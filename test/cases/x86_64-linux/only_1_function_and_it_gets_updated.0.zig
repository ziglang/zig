pub export fn _start() noreturn {
    asm volatile ("syscall"
        :
        : [number] "{rax}" (60), // exit
          [arg1] "{rdi}" (0),
        : "rcx", "r11", "memory"
    );
    unreachable;
}

// run
// target=x86_64-linux
//
