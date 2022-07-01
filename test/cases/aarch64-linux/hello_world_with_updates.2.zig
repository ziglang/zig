pub fn main() void {
    print();
    print();
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

// run
//
// Hello, World!
// Hello, World!
//
