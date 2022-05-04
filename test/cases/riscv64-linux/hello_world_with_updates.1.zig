pub fn main() void {
    print();
    print();
    print();
    print();
}

fn print() void {
    asm volatile ("ecall"
        :
        : [number] "{a7}" (64),
          [arg1] "{a0}" (1),
          [arg2] "{a1}" (@ptrToInt("Hello, World!\n")),
          [arg3] "{a2}" ("Hello, World!\n".len),
        : "rcx", "r11", "memory"
    );
    return;
}

// run
// target=riscv64-linux
//
// Hello, World!
// Hello, World!
// Hello, World!
// Hello, World!
//
