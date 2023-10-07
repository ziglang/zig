const plan9 = @import("../plan9.zig");
// TODO better inline asm

pub fn syscall1(sys: plan9.SYS, arg0: usize) usize {
    return asm volatile (
        \\push %%r8
        \\push $0
        \\syscall
        \\pop %%r11
        \\pop %%r11
        : [ret] "={rax}" (-> usize),
        : [arg0] "{r8}" (arg0),
          [syscall_number] "{rbp}" (@intFromEnum(sys)),
        : "rcx", "rax", "rbp", "r11", "memory"
    );
}
pub fn syscall2(sys: plan9.SYS, arg0: usize, arg1: usize) usize {
    return asm volatile (
        \\push %%r9
        \\push %%r8
        \\push $0
        \\syscall
        \\pop %%r11
        \\pop %%r11
        \\pop %%r11
        : [ret] "={rax}" (-> usize),
        : [arg0] "{r8}" (arg0),
          [arg1] "{r9}" (arg1),
          [syscall_number] "{rbp}" (@intFromEnum(sys)),
        : "rcx", "rax", "rbp", "r11", "memory"
    );
}
pub fn syscall3(sys: plan9.SYS, arg0: usize, arg1: usize, arg2: usize) usize {
    return asm volatile (
        \\push %%r10
        \\push %%r9
        \\push %%r8
        \\push $0
        \\syscall
        \\pop %%r11
        \\pop %%r11
        \\pop %%r11
        \\pop %%r11
        : [ret] "={rax}" (-> usize),
        : [arg0] "{r8}" (arg0),
          [arg1] "{r9}" (arg1),
          [arg2] "{r10}" (arg2),
          [syscall_number] "{rbp}" (@intFromEnum(sys)),
        : "rcx", "rax", "rbp", "r11", "memory"
    );
}
pub fn syscall4(sys: plan9.SYS, arg0: usize, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile (
        \\push %%r11
        \\push %%r10
        \\push %%r9
        \\push %%r8
        \\push $0
        \\syscall
        \\pop %%r11
        \\pop %%r11
        \\pop %%r11
        \\pop %%r11
        \\pop %%r11
        : [ret] "={rax}" (-> usize),
        : [arg0] "{r8}" (arg0),
          [arg1] "{r9}" (arg1),
          [arg2] "{r10}" (arg2),
          [arg3] "{r11}" (arg3),
          [syscall_number] "{rbp}" (@intFromEnum(sys)),
        : "rcx", "rax", "rbp", "r11", "memory"
    );
}
