export fn _start() noreturn {
    var x: usize = 0;
    exit(x);
}

fn exit(x: usize) noreturn {
    asm volatile ("syscall"
        :
        : [number] "{rax}" (231),
          [arg1] "{rdi}" (x)
        : "rcx", "r11", "memory"
    );
    unreachable;
}
