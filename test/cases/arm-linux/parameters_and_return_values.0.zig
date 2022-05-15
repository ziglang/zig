pub fn main() void {
    print(id(14));
}

fn id(x: u32) u32 {
    return x;
}

// TODO: The parameters to the asm statement in print() had to
// be in a specific order because otherwise the write to r0
// would overwrite the len parameter which resides in r0
fn print(len: u32) void {
    asm volatile ("svc #0"
        :
        : [number] "{r7}" (4),
          [arg3] "{r2}" (len),
          [arg1] "{r0}" (1),
          [arg2] "{r1}" (@ptrToInt("Hello, World!\n")),
        : "memory"
    );
    return;
}

// run
// target=arm-linux
//
// Hello, World!
//
