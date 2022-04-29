const PrintFn = *const fn () void;

pub fn main() void {
    var printFn: PrintFn = stopSayingThat;
    var i: u32 = 0;
    while (i < 4) : (i += 1) printFn();

    printFn = moveEveryZig;
    printFn();
}

fn stopSayingThat() void {
    asm volatile ("svc #0"
        :
        : [number] "{r7}" (4),
          [arg1] "{r0}" (1),
          [arg2] "{r1}" (@ptrToInt("Hello, my name is Inigo Montoya; you killed my father, prepare to die.\n")),
          [arg3] "{r2}" ("Hello, my name is Inigo Montoya; you killed my father, prepare to die.\n".len),
        : "memory"
    );
    return;
}

fn moveEveryZig() void {
    asm volatile ("svc #0"
        :
        : [number] "{r7}" (4),
          [arg1] "{r0}" (1),
          [arg2] "{r1}" (@ptrToInt("All your codebase are belong to us\n")),
          [arg3] "{r2}" ("All your codebase are belong to us\n".len),
        : "memory"
    );
    return;
}

// run
// target=arm-linux
//
// Hello, my name is Inigo Montoya; you killed my father, prepare to die.
// Hello, my name is Inigo Montoya; you killed my father, prepare to die.
// Hello, my name is Inigo Montoya; you killed my father, prepare to die.
// Hello, my name is Inigo Montoya; you killed my father, prepare to die.
// All your codebase are belong to us
//
