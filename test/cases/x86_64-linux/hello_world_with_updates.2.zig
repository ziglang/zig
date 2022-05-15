pub export fn _start() noreturn {
    print();

    exit();
}

fn print() void {
    asm volatile ("syscall"
        :
        : [number] "{rax}" (1),
          [arg1] "{rdi}" (1),
          [arg2] "{rsi}" (@ptrToInt("Hello, World!\n")),
          [arg3] "{rdx}" (14),
        : "rcx", "r11", "memory"
    );
    return;
}

fn exit() noreturn {
    asm volatile ("syscall"
        :
        : [number] "{rax}" (231),
          [arg1] "{rdi}" (0),
        : "rcx", "r11", "memory"
    );
    unreachable;
}

// run
//
// Hello, World!
//
