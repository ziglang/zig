pub fn main() void {
    comptime var len: u32 = 5;
    print(len);
    len += 9;
    print(len);
}

fn print(len: usize) void {
    asm volatile ("syscall"
        :
        : [number] "{rax}" (1),
          [arg1] "{rdi}" (1),
          [arg2] "{rsi}" (@ptrToInt("Hello, World!\n")),
          [arg3] "{rdx}" (len),
        : "rcx", "r11", "memory"
    );
}

// run
//
// HelloHello, World!
//
