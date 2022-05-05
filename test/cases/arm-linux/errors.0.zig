pub fn main() void {
    foo() catch print();
}

fn foo() anyerror!void {}

fn print() void {
    asm volatile ("svc #0"
        :
        : [number] "{r7}" (4),
          [arg1] "{r0}" (1),
          [arg2] "{r1}" (@ptrToInt("Hello, World!\n")),
          [arg3] "{r2}" ("Hello, World!\n".len),
        : "memory"
    );
    return;
}

// run
// target=arm-linux
//
