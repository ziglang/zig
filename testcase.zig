export fn _start() noreturn {
    assert(add(3, 4) == 7);
    assert(add(20, 10) == 30);

    exit();
}

fn add(a: u32, b: u32) u32 {
    var x: u32 = undefined;
    x = 0;
    x += a;
    x += b;
    return x;
}

pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

fn exit() noreturn {
    asm volatile ("syscall"
        :
        : [number] "{rax}" (231),
          [arg1] "{rdi}" (0)
        : "rcx", "r11", "memory"
    );
    unreachable;
}
