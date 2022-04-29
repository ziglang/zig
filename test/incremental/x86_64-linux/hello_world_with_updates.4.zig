pub fn main() void {
    print();
}

fn print() void {
    asm volatile ("syscall"
        :
        : [number] "{rax}" (1),
          [arg1] "{rdi}" (1),
          [arg2] "{rsi}" (@ptrToInt("What is up? This is a longer message that will force the data to be relocated in virtual address space.\n")),
          [arg3] "{rdx}" (104),
        : "rcx", "r11", "memory"
    );
    return;
}

// run
//
// What is up? This is a longer message that will force the data to be relocated in virtual address space.
//
