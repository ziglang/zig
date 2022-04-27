pub export fn _start() noreturn {
    asm volatile ("syscall"
        :
        : [number] "{rax}" (231), // exit_group
          [arg1] "{rdi}" (0),
        : "rcx", "r11", "memory"
    );
    unreachable;
}

// run
//
