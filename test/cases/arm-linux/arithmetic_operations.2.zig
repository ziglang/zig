pub fn main() void {
    print(8, 9);
    print(3, 7);
}

fn print(a: u32, b: u32) void {
    asm volatile ("svc #0"
        :
        : [number] "{r7}" (4),
          [arg3] "{r2}" (a & b),
          [arg1] "{r0}" (1),
          [arg2] "{r1}" (@ptrToInt("123456789")),
        : "memory"
    );
    return;
}

// run
//
// 12345678123
