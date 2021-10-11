const plan9 = @import("../plan9.zig");
// TODO get ret from inline asm
// TODO better inline asm

pub fn syscall4(sys: plan9.SYS, arg0: usize, arg1: usize, arg2: usize, arg3: usize) void {
    asm volatile (
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
        :
        : [arg0] "{r8}" (arg0),
          [arg1] "{r9}" (arg1),
          [arg2] "{r10}" (arg2),
          [arg2] "{r11}" (arg3),
          [syscall_number] "{rbp}" (@enumToInt(sys)),
        : "rcx", "rbp", "r11", "memory"
    );
}
pub fn syscall1(sys: plan9.SYS, arg0: usize) void {
    _ = sys;
    asm volatile (
        \\push %%r8
        \\push $0
        \\syscall
        \\pop %%r11
        \\pop %%r11
        :
        : [syscall_number] "{rbp}" (@enumToInt(sys)),
          [arg0] "{r8}" (arg0),
        : "rcx", "rbp", "r11", "memory"
    );
}
