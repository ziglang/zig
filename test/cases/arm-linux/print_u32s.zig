pub fn main() void {
    printNumberHex(0x00000000);
    printNumberHex(0xaaaaaaaa);
    printNumberHex(0xdeadbeef);
    printNumberHex(0x31415926);
}

fn printNumberHex(x: u32) void {
    var i: u5 = 28;
    while (true) : (i -= 4) {
        const digit = (x >> i) & 0xf;
        asm volatile ("svc #0"
            :
            : [number] "{r7}" (4),
              [arg1] "{r0}" (1),
              [arg2] "{r1}" (@ptrToInt("0123456789abcdef") + digit),
              [arg3] "{r2}" (1),
            : "memory"
        );

        if (i == 0) break;
    }
    asm volatile ("svc #0"
        :
        : [number] "{r7}" (4),
          [arg1] "{r0}" (1),
          [arg2] "{r1}" (@ptrToInt("\n")),
          [arg3] "{r2}" (1),
        : "memory"
    );
}

// run
// target=arm-linux
//
// 00000000
// aaaaaaaa
// deadbeef
// 31415926
//
