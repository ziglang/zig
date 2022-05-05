pub export fn _start() noreturn {
    print();
    print();
    print();
    print();
    exit(0);
}

fn print() void {
    asm volatile ("svc #0"
        :
        : [number] "{x8}" (64),
          [arg1] "{x0}" (1),
          [arg2] "{x1}" (@ptrToInt("Hello, World!\n")),
          [arg3] "{x2}" ("Hello, World!\n".len),
        : "memory", "cc"
    );
}

fn exit(ret: usize) noreturn {
    asm volatile ("svc #0"
        :
        : [number] "{x8}" (93),
          [arg1] "{x0}" (ret),
        : "memory", "cc"
    );
    unreachable;
}

// run
//
// Hello, World!
// Hello, World!
// Hello, World!
// Hello, World!
//
