pub fn main() void {
    print();
    print();
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

// run
//
// Hello, World!
// Hello, World!
//
