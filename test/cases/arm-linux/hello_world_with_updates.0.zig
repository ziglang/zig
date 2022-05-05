pub export fn _start() noreturn {
    print();
    exit();
}

fn print() void {
    asm volatile ("svc #0"
        :
        : [number] "{r7}" (4),
          [arg1] "{r0}" (1),
          [arg2] "{r1}" (@ptrToInt("Hello, World!\n")),
          [arg3] "{r2}" (14),
        : "memory"
    );
    return;
}

fn exit() noreturn {
    asm volatile ("svc #0"
        :
        : [number] "{r7}" (1),
          [arg1] "{r0}" (0),
        : "memory"
    );
    unreachable;
}

// run
// target=arm-linux
//
// Hello, World!
//
