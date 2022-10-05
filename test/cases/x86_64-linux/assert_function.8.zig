pub fn main() void {
    var i: u32 = 0;
    inline while (i < 4) : (i += 1) print();
    assert(i == 4);
}

fn print() void {
    asm volatile ("syscall"
        :
        : [number] "{rax}" (1),
          [arg1] "{rdi}" (1),
          [arg2] "{rsi}" (@ptrToInt("hello\n")),
          [arg3] "{rdx}" (6),
        : "rcx", "r11", "memory"
    );
}

pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

// error
//
// :3:21: error: unable to resolve comptime value
// :3:21: note: condition in comptime branch must be comptime-known
